classdef simAbstractSig < handle
   
    properties
        local_matlab_name
        local_source_block
        local_source_port
        redirect_sig
    end
    
    methods
        
        function obj = simAbstractSig(src_blk_obj,src_port)
            obj.local_source_block = src_blk_obj;
            obj.local_source_port = src_port;
            obj.local_matlab_name = sprintf('%s/Output%d',src_blk_obj.matlab_name,src_port);
            obj.redirect_sig = [];
        end
        
        function redirectSig(cur_sig_obj, new_sig_obj)
            cur_sig_obj.redirect_sig = new_sig_obj;
        end
        
        function blk_obj = resolve(obj)
            if isempty(obj.redirect_sig)
                blk_obj = obj;
            else
                blk_obj = obj.redirect_sig.resolve;
            end
        end
        
        function name = matlab_name(obj)
            name = obj.resolve.local_matlab_name;
        end
        
        function disp(obj)
            disp(obj.matlab_name)
        end
        
    end
    
end