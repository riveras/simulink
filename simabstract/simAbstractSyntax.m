classdef simAbstractSyntax < handle
    
    properties
        blocks
        signals
    end
    
    methods
        function obj = simAbstractSyntax(mdl_name)
            blk_names = find_system(mdl_name);
            for ii=1:numel(blk_names),
                obj.blocks{ii}=simAbstractBlk(blk_names{ii});
                obj.findOutputSignals(obj.blocks{ii})
            end
            for ii=1:numel(obj.blocks),
                obj.connectInputSignals(obj.blocks{ii});
            end
            for ii=1:numel(obj.blocks),
                this_blk = obj.blocks{ii};
                if this_blk.isOutport(),
                    obj.redirectOutport(this_blk);
                elseif this_blk.isInport(),
                    obj.redirectInport(this_blk);
                end
            end
        end
        
        function disp(obj)
            for ii=1:numel(obj.signals),
                obj.signals{ii}.disp();
            end
            for ii=1:numel(obj.blocks),
                obj.blocks{ii}.disp();
            end
        end
        
        function n = num_blocks(obj)
            n = numel(obj.blocks);
        end
        
        function n = num_signals(obj)
            n = numel(obj.signals);
        end
        
        function findOutputSignals(obj,blk_obj)
            port_conn = [];
            try
                port_conn = get_param(blk_obj.matlab_name,'PortConnectivity');
            catch
                warning('Unable to parse output signals for block: %s', blk_obj.matlab_name)
            end
            for ii=1:numel(port_conn),
                conn = port_conn(ii);
                if ~isempty(conn.DstPort),
                    port_num = str2num(conn.Type);
                    new_sig_obj = simAbstractSig(blk_obj,port_num);
                    blk_obj.addNewBlkOutput(new_sig_obj,port_num);
                    obj.addNewSignal(new_sig_obj);
                end
            end
        end
        
        function addNewSignal(obj,sig_obj)
            num_signals = numel(obj.signals);
            obj.signals{num_signals+1}=sig_obj;
        end
        
        function connectInputSignals(obj,blk_obj)
            port_conn = [];
            blk_name = blk_obj.matlab_name;
            try
                port_conn = get_param(blk_name,'PortConnectivity');
            catch
                warning('Unable to parse input signals for block: %s', blk_obj.matlab_name)
            end
            for ii=1:numel(port_conn),
                conn = port_conn(ii);
                if ~isempty(conn.SrcPort),
                    in_port_num = str2num(conn.Type);
                    assert(numel(conn.SrcPort)==1)
                    assert(numel(conn.SrcBlock)==1)
                    src_port_num = conn.SrcPort+1;
                    src_blk_hdl = conn.SrcBlock;
                    src_blk_obj = obj.getBlockByHandle(src_blk_hdl);
                    src_sig_obj = src_blk_obj.outputs{src_port_num};
                    blk_obj.addNewBlkInput(src_sig_obj,in_port_num);
                end
            end
        end
        
        function blk_obj = getBlockByHandle(obj,blk_hdl)
            blk_obj = [];
            for ii = 1:numel(obj.blocks),
                if obj.blocks{ii}.handle == blk_hdl,
                    blk_obj = obj.blocks{ii};
                    break
                end
            end
        end
        
        function blk_obj = getBlockByMatlabName(obj,seek_mat_name)
            blk_obj = [];
            for ii = 1:numel(obj.blocks),
                if strcmp(obj.blocks{ii}.matlab_name,seek_mat_name),
                    blk_obj = obj.blocks{ii};
                    break
                end
            end
        end
        
        function redirectOutport(obj,blk_obj)
            %fprintf('%s is an outport\n',blk_obj.matlab_name)
            outport_in_sig = blk_obj.inputs{1};
            parent_name = get_param(blk_obj.matlab_name,'Parent');
            port_num = str2num(get_param(blk_obj.matlab_name,'Port'));
            parent_blk_obj = obj.getBlockByMatlabName(parent_name);
            parent_out_sig = parent_blk_obj.outputs{port_num};
            parent_out_sig.redirectSig(outport_in_sig);
        end
        
        function redirectInport(obj,blk_obj)
            %fprintf('%s is an inport\n',blk_obj.matlab_name)
            inport_out_sig = blk_obj.outputs{1};
            parent_name = get_param(blk_obj.matlab_name,'Parent');
            port_num = str2num(get_param(blk_obj.matlab_name,'Port'));
            parent_blk_obj = obj.getBlockByMatlabName(parent_name);
            parent_in_sig = parent_blk_obj.inputs{port_num};
            inport_out_sig.redirectSig(parent_in_sig);
        end
        
    end
    
end