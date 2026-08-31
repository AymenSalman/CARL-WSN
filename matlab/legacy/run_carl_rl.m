function [net, latency] = run_carl_rl(node_id, pkt_class, net, params, mode_selected)
% RUN_CARL_RL  Execute routing with energy-aware relay selection
%   Wraps the standard routing modes with energy-aware next-hop preference

switch mode_selected
    case 'proactive'
        % Use energy-aware relay for proactive forwarding
        next_hop = select_energy_aware_hop(node_id, net, params);
        
        if next_hop == node_id
            % Fallback to standard proactive
            [net, latency] = routing_proactive(node_id, pkt_class, net, params);
        else
            % Forward to energy-aware next hop
            d = sqrt((net.x(node_id) - net.x(next_hop))^2 + ...
                     (net.y(node_id) - net.y(next_hop))^2);
            
            % Transmit energy
            d0 = params.d0;
            if d < d0
                e_tx = params.L * params.E_elec + params.L * params.eps_fs * d^2;
            else
                e_tx = params.L * params.E_elec + params.L * params.eps_mp * d^4;
            end
            e_rx = params.L * params.E_elec;
            
            net.energy(node_id) = max(net.energy(node_id) - e_tx, 0);
            net.energy(next_hop) = max(net.energy(next_hop) - e_rx, 0);
            
            % Proactive table maintenance overhead (10% of tx energy)
            net.energy(node_id) = max(net.energy(node_id) - e_tx * 0.10, 0);
            
            % Check deaths
            net = check_node_death(net, node_id, params);
            net = check_node_death(net, next_hop, params);
            
            % Record delivery
            net.metrics.total_sent = net.metrics.total_sent + 1;
            net.metrics.delivered = net.metrics.delivered + 1;
           latency = 15 + rand() * 5;  % proactive: ~17.5ms avg
            
            if strcmp(pkt_class, 'A')
                net.metrics.latency_A = [net.metrics.latency_A, latency];
            end
        end
        
    case 'reactive'
        % Use energy-aware relay for reactive discovery
        next_hop = select_energy_aware_hop(node_id, net, params);
        
        if next_hop == node_id
            [net, latency] = routing_reactive(node_id, pkt_class, net, params);
        else
            d = sqrt((net.x(node_id) - net.x(next_hop))^2 + ...
                     (net.y(node_id) - net.y(next_hop))^2);
            
            d0 = params.d0;
            if d < d0
                e_tx = params.L * params.E_elec + params.L * params.eps_fs * d^2;
            else
                e_tx = params.L * params.E_elec + params.L * params.eps_mp * d^4;
            end
            e_rx = params.L * params.E_elec;
            
            net.energy(node_id) = max(net.energy(node_id) - e_tx, 0);
            net.energy(next_hop) = max(net.energy(next_hop) - e_rx, 0);
            
            net = check_node_death(net, node_id, params);
            net = check_node_death(net, next_hop, params);
            
            net.metrics.total_sent = net.metrics.total_sent + 1;
            net.metrics.delivered = net.metrics.delivered + 1;
           latency = 85 + rand() * 30;  % reactive: ~100ms avg
            
            if strcmp(pkt_class, 'A')
                net.metrics.latency_A = [net.metrics.latency_A, latency];
            end
        end
        
    case 'hybrid'
        % Use energy-aware relay for hybrid mode
        next_hop = select_energy_aware_hop(node_id, net, params);
        
        if next_hop == node_id
            [net, latency] = routing_hybrid(node_id, pkt_class, net, params);
        else
            d = sqrt((net.x(node_id) - net.x(next_hop))^2 + ...
                     (net.y(node_id) - net.y(next_hop))^2);
            
            d0 = params.d0;
            if d < d0
                e_tx = params.L * params.E_elec + params.L * params.eps_fs * d^2;
            else
                e_tx = params.L * params.E_elec + params.L * params.eps_mp * d^4;
            end
            e_rx = params.L * params.E_elec;
            
            net.energy(node_id) = max(net.energy(node_id) - e_tx, 0);
            net.energy(next_hop) = max(net.energy(next_hop) - e_rx, 0);
            
            % Zone maintenance overhead (5%)
            net.energy(node_id) = max(net.energy(node_id) - e_tx * 0.05, 0);
            
            net = check_node_death(net, node_id, params);
            net = check_node_death(net, next_hop, params);
            
            net.metrics.total_sent = net.metrics.total_sent + 1;
            net.metrics.delivered = net.metrics.delivered + 1;
           latency = 18 + rand() * 10;  % hybrid: ~23ms avg
            
            if strcmp(pkt_class, 'A')
                net.metrics.latency_A = [net.metrics.latency_A, latency];
            end
        end
end

end

function net = check_node_death(net, node_id, params)
    if net.energy(node_id) <= 0 && net.alive(node_id)
        net.alive(node_id) = false;
        dead_count = sum(~net.alive(1:params.N));
        if net.FND == 0
            net.FND = net.round;
            fprintf('  >> FND at round %d (node %d died)\n', net.round, node_id);
        end
        if net.HND == 0 && dead_count >= floor(params.N / 2)
            net.HND = net.round;
            fprintf('  >> HND at round %d (%d nodes dead)\n', net.round, dead_count);
        end
    end
end