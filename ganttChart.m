classdef ganttChart < matlab.graphics.chartcontainer.ChartContainer
    % ganttChart Visualize the start and end dates of tasks in a project.
    %
    % By default, events are arranged vertically and are ordered based on
    % the order of the input.
    %
    % ganttChart(TaskData, DurationData) creates a bar for each task. The
    % length of the bar represents the duration of the respective task.
    % Each task's start date is the previous task's end date. The first
    % task starts at the current time.
    %
    % ganttChart(TaskData, StartDate, EndDate) creates a bar for each task
    % as described above. The bar's length corresponds to the duration
    % between a given start and end date.
    %
    % ganttChart(TaskData, StartDate, DurationData) creates a bar for each
    % task. The end date is calculated by adding a given duration to the
    % respective start date.
    %
    % ganttChart(TaskData, DurationData, EndDate) creates a bar for
    % each task. The start dates of the tasks are calculated by subtracting
    % the duration from the task's end date, to find the latest start date.
    %
    % ganttChart(____, Name, Value) specifies additional options for the
    % chart using one or more name-value pair arguments. Specify the
    % options after all other input arguments.
    %
    % ganttChart(target,___) plots into target instead of GCF.
    %
    % f = ganttChart(___) returns the ganttChart object. Use f to modify
    % properties of the chart after creating it.
    %
    % Copyright 2022 The MathWorks, Inc.

    properties
        TaskData (1,:) string {mustBeText} = ''
        DurationData (1,:) duration = duration.empty()
        StartDate (1,:) datetime {mustBeFinite} = datetime.empty()

        Title (1,:) {mustBeText} = ''
        TaskAxisLabel (1,:) {mustBeText} = ''
        TimeAxisLabel (1,:) {mustBeText} = ''
        FaceColor {mustBeValidColor} = [0 0.4471 0.7412]
        EdgeColor {mustBeValidSingleColor} = [0 0 0]
        Grid {mustBeValidGrid} = 'columns'
        BarWidth (1,1) double {mustBeNumeric, mustBePositive, mustBeLessThanOrEqual(BarWidth, 1)} = 0.5
        LineWidth (1,1) double {mustBeNumeric, mustBePositive} = 0.5

        ShowNowLine (1,1) matlab.lang.OnOffSwitchState = false
        NowLineColor {mustBeValidSingleColor} = [0.8510 0.3255 0.0980]
        NowLineStyle (1,:) char {mustBeMember(NowLineStyle, {'-', '--', ':', '-.'})} = '--'
    end

    properties(Access = private, Transient, NonCopyable)
        BarObjects (1,:) matlab.graphics.primitive.Patch
        NowLine (:,1) matlab.graphics.chart.decoration.ConstantLine
    end

    methods
        function obj = ganttChart(varargin)
 
            % Initialize list of arguments
            args = varargin;
            leadingArgs = cell(0);
             
            % Check if the first input argument is a graphics object to use as parent.
            if ~isempty(args) && isa(args{1},'matlab.graphics.Graphics')
                % ganttChart(parent, ___)
                leadingArgs = args(1);
                args = args(2:end);
            end

            if ~isempty(args)
                if numel(args) < 2
                    error("Insufficient input arguments, Gantt chart requires at least 2.");
                elseif ~isduration(args{2}) && ~isdatetime(args{2})
                    error("Second argument must be of type duration or datetime.");
                end
            end
             
            % Check for optional positional arguments.
            if ~isempty(args) && (ischar(args{1}) || isstring(args{1}) || iscell(args{1}))
                if mod(numel(args), 2) == 0 && isduration(args{2})
                    % ganttChart(TaskData, DurationData)
                    % ganttChart(TaskData, DurationData, Name, Value)
                    tasks = args{1};
                    duration = args{2};

                    if ~isempty(duration)
                        endDate = datetime() + cumsum(duration(:));
                        start = [datetime() endDate(1:end-1)'];
                    else
                        start = datetime.empty(length(duration), width(duration));
                    end

                    mustBeValidSize(tasks, start, duration);
                    
                    leadingArgs = [leadingArgs {'TaskData', tasks, 'StartDate', start, 'DurationData', duration}];
                    args = args(4:end);

                elseif numel(args) >= 3 && mod(numel(args), 2) == 1 && isdatetime(args{2})
                    if isdatetime(args{3})
                        % ganttChart(TaskData, StartDate, EndDate)
                        % ganttChart(TaskData, StartDate, EndDate, Name, Value)
                        tasks = args{1};
                        start = args{2};
                        endDate = args{3};

                        % Validation before calculation of inputs
                        if numel(start) ~= numel(endDate)
                            error("Start and end dates must be the same size.");
                        end
                        
                        duration = endDate - start;
                        mustBeValidSize(tasks, start, duration);
                        
                        % Convert duration to days if necessary
                        if ~isempty(duration) && all(mod(duration, hours(24)) == 0)
                            duration = days(days(duration));
                        end
     
                        leadingArgs = [leadingArgs {'TaskData', tasks, 'StartDate', start, 'DurationData', duration}];
                        args = args(4:end);

                    elseif isduration(args{3})
                        % ganttChart(TaskData, StartDate, DurationData)
                        % ganttChart(TaskData, StartDate, DurationData, Name, Value)
                        tasks = args{1};
                        start = args{2};
                        duration = args{3};

                        mustBeValidSize(tasks, start, duration);
    
                        leadingArgs = [leadingArgs {'TaskData', tasks, 'StartDate', start, 'DurationData', duration}];
                        args = args(4:end);
                    else
                        error("Third argument must be either of type datetime or duration.");
                    end
                    
                elseif numel(args) >= 3 && isduration(args{2}) && isdatetime(args{3})
                    % ganttChart(TaskData, DurationData, EndDate)
                    % ganttChart(TaskData, DurationData, EndDate, Name, Value)
                    tasks = args{1};
                    duration = args{2};
                    endDate = args{3};

                    % Validation before calculation of inputs
                    if numel(endDate) ~= numel(duration)
                        error("Duration data and end dates should be the same size.");
                    end

                    start = endDate - duration;
                    mustBeValidSize(tasks, start, duration);

                    leadingArgs = [leadingArgs {'TaskData', tasks, 'DurationData', duration, 'StartDate', start}];
                    args = args(4:end);                    
                end
            end
             
            % Combine positional arguments with name/value pairs.
            args = [leadingArgs args];
             
            % Call superclass constructor method
            obj@matlab.graphics.chartcontainer.ChartContainer(args{:});
        end

        function set.Grid(obj, value)
            obj.Grid = mustBeValidGrid(value);
        end

        function set.FaceColor(obj, color)
            obj.FaceColor = mustBeValidColor(color);
        end

        function set.EdgeColor(obj, color)
            obj.EdgeColor = mustBeValidSingleColor(color);
        end
        
        function set.NowLineColor(obj, color)
            obj.NowLineColor = mustBeValidSingleColor(color);
        end

        function set.TimeAxisLabel(obj, label)
            xlabel(getAxes(obj), label);
        end

        function lbl = get.TimeAxisLabel(obj)
            ax = getAxes(obj);
            lbl = ax.XLabel.String;
        end

        function set.TaskAxisLabel(obj, label)
            ylabel(getAxes(obj), label);
        end

        function lbl = get.TaskAxisLabel(obj)
            ax = getAxes(obj);
            lbl = ax.YLabel.String;
        end

        function set.Title(obj, t)
            title(getAxes(obj), t);
        end

        function t = get.Title(obj)
            ax = getAxes(obj);
            t = ax.Title.String;
        end
    end

    methods(Access = protected)
        function setup(obj)
            % Create the axes
            ax = getAxes(obj);
            set(ax, 'Box', 'on');
                
            % Create graphics objects
            obj.BarObjects = patch(ax, NaT, NaN, 'k');
            obj.NowLine = xline(ax, NaT);
            obj.NowLine.Visible = "off";
            obj.NowLine.LineStyle = "--";
            configureDataTip(obj.BarObjects);

            % Initialize the axis
            ax.YDir = 'reverse';
            ax.XLimitMethod = 'tight';
            ax.XAxisLocation = 'top';

        end
 
        function update(obj)
            ax = getAxes(obj);

            mustBeValidSize(obj.TaskData, obj.StartDate, obj.DurationData);

            % Set task labels and y-values
            yticks(ax, 1:numel(obj.TaskData));
            ylim(ax, [0.25 numel(obj.TaskData) + 0.75]);
            yticklabels(ax, obj.TaskData);   
            ax.TickLength = [0 0];
         
            % Find y-coordinates of vertices
            ticks = 1:numel(obj.TaskData);
            points = [ticks - obj.BarWidth/2; ticks + obj.BarWidth/2]';
            y = [points fliplr(points)];           

            % Find x-coordinates of each bar   
            endDate = obj.StartDate' + obj.DurationData';
            x = [obj.StartDate' obj.StartDate' endDate endDate];

            % Set data after validation
            obj.BarObjects.XData = x';
            obj.BarObjects.YData = y';
            
            % Update grid lines
            if isequal(obj.Grid, 'columns')
                ax.XGrid = 'on';
                ax.YGrid = 'off';
            else
                grid(ax, obj.Grid);
            end

            % Update bar color and style
            obj.BarObjects.FaceVertexCData = getColors(numel(obj.TaskData), obj.FaceColor);
            obj.BarObjects.FaceColor = "flat";
            obj.BarObjects.EdgeColor = obj.EdgeColor;
            obj.BarObjects.LineWidth = obj.LineWidth;
           
            % Update the line at today's date
            obj.NowLine.Visible = obj.ShowNowLine;
            if obj.NowLine.Visible
                obj.NowLine.Value = datetime;
                obj.NowLine.Color = obj.NowLineColor;
                obj.NowLine.LineStyle = obj.NowLineStyle;

                % Update x-limits to add padding if the now line is at the
                % edge of the figure
                xlimits = ax.XLim;
                val = diff(xlimits)/15;

                % Extend the left or right x-limits if the now line is
                % within a certain distance from the edge
                if abs(xlimits(2) - datetime()) <= val
                    xlim(ax, [xlimits(1), xlimits(2) + val]);
                elseif abs(xlimits(1) - datetime()) <= val
                    xlim(ax, [xlimits(1) - val, xlimits(2)]);
                end
            else
                % Set tight x-limits if no now line
                ax.XLimMode = 'auto';
                ax.XLimitMethod = 'tight';
            end
            
            % Update data tip labels
            dtt = obj.BarObjects.DataTipTemplate;
            rows = dtt.DataTipRows;
            rows(1).Value = repelem(obj.TaskData, 4);
            rows(3).Value = repelem(obj.DurationData, 4);
            dtt.DataTipRows = rows;
        end
    end

    methods
        function stagger(obj, taskOne, taskTwo)
            arguments
                obj
                taskOne (1,1) string
                taskTwo (1,1) string
            end

            idxOne = find(strcmp(obj.TaskData, taskOne));
            idxTwo = find(strcmp(obj.TaskData, taskTwo));

            if isempty(idxOne)
                error("Task one not found in task list.");
            elseif isempty(idxTwo)
                error("Task two not found in task list.");
            end

            % If more than one task has the same name, choose the first
            % matching one by default
            if numel(idxOne) > 1
                idxOne = idxOne(1);
            elseif numel(idxTwo) > 1
                idxTwo = idxTwo(1);
            end

            startDateOne = obj.StartDate(idxOne);
            startDateTwo = obj.StartDate(idxTwo);

            endDateOne = startDateOne + obj.DurationData(idxOne);
            endDateTwo = startDateTwo + obj.DurationData(idxTwo);

            % Shift task with the overlapping start date down after the
            % other task
            if isbetween(startDateOne, startDateTwo, endDateTwo, 'open')
                shiftTask(obj, idxOne, endDateOne, endDateTwo)
            elseif isbetween(startDateTwo, startDateOne, endDateOne, 'open')
                shiftTask(obj, idxTwo, endDateTwo, endDateOne);
            elseif isequal(startDateOne, startDateTwo)
                [~, I] = min([endDateOne, endDateTwo], [], 'all');

                % Shift the task with the earlier end date
                if I == 1
                    shiftTask(obj, idxOne, endDateOne, endDateTwo);
                elseif I == 2
                    shiftTask(obj, idxTwo, endDateTwo, endDateOne);
                end

            else
                disp("Tasks do not overlap.");
            end
        end

        function addTask(obj, task, dur, startDate)
            arguments
                obj
                task (1,:) string
                dur (1,:) duration
                startDate (1,:) datetime
            end

            mustBeValidSize(task, dur, startDate);

            obj.TaskData = horzcat(obj.TaskData, task);
            obj.DurationData = horzcat(obj.DurationData, dur);
            obj.StartDate = horzcat(obj.StartDate, startDate);
        end

        function sort(obj, order)
            arguments
                obj
                order (1,1) string {mustBeMember(order, ["ascend","descend"])} = "ascend"
            end

            [obj.StartDate, idx] = sort(obj.StartDate, order);
            obj.TaskData = obj.TaskData(idx);
            obj.DurationData = obj.DurationData(idx);
        end
    end
end
 
function value = mustBeValidGrid(value)
    if islogical(value) && isscalar(value)
        if value 
            value = 'on';
        else
            value = 'off';
        end
    end
    value = string(lower(value));
    mustBeMember(value, {'on', 'off', 'columns'})
end

function colors = getColors(numOfTasks, colors)
    idx = mod((1:numOfTasks)-1, height(colors)) + 1;
    colors = colors(idx,:);
end

function colors = mustBeValidColor(colors)
    assert(height(colors) >= 1, "FaceColor must have at least one color.");
    colors = validatecolor(colors, 'multiple');
end

function color = mustBeValidSingleColor(color)
    color = validatecolor(color);
end

function mustBeValidSize(tasks, start, duration)
    if numel(tasks) ~= numel(start)
        error("The number of tasks should be the same size as the number of start dates.");
    elseif numel(start) ~= numel(duration)
        error("Start date and duration data must be the same size.");
    end
end

function configureDataTip(patchHandle)
    delete(datatip(patchHandle));
    timeRow = patchHandle.DataTipTemplate.DataTipRows(1);
    taskRow = dataTipTextRow('Task', string.empty());
    durationRow = dataTipTextRow('Duration', duration.empty());
    
    timeRow.Label = 'Time';
    patchHandle.DataTipTemplate.DataTipRows = [taskRow; timeRow; durationRow];
end

function shiftTask(ganttChartHandle, taskIdxOne, endDateOne, endDateTwo)
    originalDur = endDateOne - ganttChartHandle.StartDate(taskIdxOne);
    ganttChartHandle.StartDate(taskIdxOne) = endDateTwo;
    ganttChartHandle.DurationData(taskIdxOne) = originalDur;
end
