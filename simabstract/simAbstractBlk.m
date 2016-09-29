classdef simAbstractBlk < handle
    properties
        matlab_name
        handle
        outputs
        inputs
        block_type
        mask_type
    end
    
    methods
        
        function obj=simAbstractBlk(matlab_name)
            obj.matlab_name = matlab_name;
            obj.handle = get_param(matlab_name,'Handle');
            try
                obj.block_type = get_param(matlab_name,'BlockType');
            catch
                warning('Unable to determine BlockType for %s',matlab_name)
            end
            try
                obj.mask_type = get_param(matlab_name,'MaskType');
            catch
                warning('Unable to determine MaskType for %s',matlab_name)
            end
        end
        
        function addNewBlkOutput(self,new_sig_obj,port_num)
            self.outputs{port_num} = new_sig_obj;
        end
        
        function addNewBlkInput(self,new_sig_obj,port_num)
            self.inputs{port_num} = new_sig_obj;
        end
        
        function flag=isInport(self)
            flag = strcmp(self.block_type,'Inport');
        end
        
        function flag=isOutport(self)
            flag = strcmp(self.block_type,'Outport');
        end
        
        function disp(obj)
            fprintf('\n*** BLOCK: %s (%s / %s) ***\n',obj.matlab_name,obj.block_type,obj.mask_type);
            disp('INPUTS');
            for ii=1:numel(obj.inputs),
                obj.inputs{ii}.disp();
            end
            disp('OUTPUTS');
            for ii=1:numel(obj.outputs),
                obj.outputs{ii}.disp();
            end
        end
        
        function n=num_inputs(obj)
            n = numel(obj.inputs);
        end
        
        function n=num_outputs(obj)
            n = numel(obj.outputs);
        end
        
    end
end