function [fitness, dispatch_info] = objective_function(particle, params)
    % 解包参数
    time_windows = params.time_windows;
    time = params.time;
    work_time = params.work_time;
    max_interrupt_time = params.max_interrupt_time;
    num_trucks = params.num_trucks;
    penalty = params.penalty;
    num_sites = size(time_windows, 1);
    
    % 初始化记录数组
    actual_dispatch_time = zeros(1, length(particle));
    travel_to_site = zeros(1, length(particle));
    travel_back_site = zeros(1, length(particle));
    arrival_times = zeros(1, length(particle));
    site_set_start_times = zeros(1, length(particle));
    work_start_times = zeros(1, length(particle));
    finish_time_site = zeros(1, length(particle));
    return_times = zeros(1, length(particle));
    truck_waiting_times = zeros(1, length(particle));
    site_waiting_times = zeros(1, length(particle));
    
    % 追踪卡车可用时间
    truck_availability = zeros(1, num_trucks);
    
    % 初始化惩罚计数
    penalty_side_time = 0;  % 工地等待惩罚
    penalty_truck_time = 0; % 卡车等待惩罚
    
    % 遍历每个派遣任务
    for k = 1:length(particle)
        site_id = round(particle(k));  % 确保工地编号为整数
        
        if site_id < 1 || site_id > num_sites
            fitness = inf;
            dispatch_info = [];
            return;
        end
        
        % 记录工地相关时间
        travel_to_site(k) = time(site_id, 1);
        travel_back_site(k) = time(site_id, 2);
        site_set_start_times(k) = time_windows(site_id, 1);
        
        % 分配卡车和计算派遣时间
        if k <= num_trucks
            truck_id = k;
            actual_dispatch_time(k) = time_windows(site_id, 1) - travel_to_site(k);
        else
            [next_available_time, truck_id] = min(truck_availability);
            actual_dispatch_time(k) = next_available_time;
        end
        
        % 计算到达时间
        arrival_times(k) = actual_dispatch_time(k) + travel_to_site(k);
        
        % 检查之前是否有卡车在该工地工作
        previous_work_idx = find(particle(1:k-1) == site_id, 1, 'last');
        
        % 确定工作开始时间
        if isempty(previous_work_idx)
            work_start_times(k) = max(arrival_times(k), site_set_start_times(k));
        else
            work_start_times(k) = max(arrival_times(k), finish_time_site(previous_work_idx));
        end
        
        % 计算完成时间和返回时间
        finish_time_site(k) = work_start_times(k) + work_time(site_id);
        return_times(k) = finish_time_site(k) + travel_back_site(k);
        truck_availability(truck_id) = return_times(k);
        
        % 计算等待时间和惩罚
        if ~isempty(previous_work_idx)
            if arrival_times(k) < finish_time_site(previous_work_idx)
                truck_waiting_times(k) = finish_time_site(previous_work_idx) - arrival_times(k);
                penalty_truck_time = penalty_truck_time + truck_waiting_times(k);
            elseif arrival_times(k) > finish_time_site(previous_work_idx)
                site_waiting_times(k) = arrival_times(k) - finish_time_site(previous_work_idx);
                if site_waiting_times(k) > max_interrupt_time(site_id)
                    penalty_side_time = penalty_side_time + 1;
                end
            end
        else
            if arrival_times(k) < site_set_start_times(k)
                truck_waiting_times(k) = site_set_start_times(k) - arrival_times(k);
                penalty_truck_time = penalty_truck_time + truck_waiting_times(k);
            else
                site_waiting_times(k) = arrival_times(k) - site_set_start_times(k);
                if site_waiting_times(k) > max_interrupt_time(site_id)
                    penalty_side_time = penalty_side_time + 1;
                end
            end
        end
    end
    
    % 计算总惩罚值（与GA相同的计算方式）
    total_penalty = penalty_side_time * penalty + penalty_truck_time;
    fitness = total_penalty;
    
    % 构建调度信息输出
    dispatch_info = struct(...
        'actual_dispatch_time', actual_dispatch_time, ...
        'arrival_times', arrival_times, ...
        'work_start_times', work_start_times, ...
        'finish_times', finish_time_site, ...
        'return_times', return_times, ...
        'truck_waiting_times', truck_waiting_times, ...
        'site_waiting_times', site_waiting_times ...
    );
end