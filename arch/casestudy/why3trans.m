% get block list
blkList = find_system(gcs,'Type','Block');

% diagram name
diagName = bdroot;

% initialize signal list
sigList = {};
thyList = {};

% loop through blocks
for ii=1:numel(blkList),
    
    % block name
    thisBlkName = blkList{ii};
    shortName = ['s_' thisBlkName((2+numel(diagName)):end)];
    % fix funny characters
    shortName(regexp(shortName,'\W'))='_';
    
    % get it's block connectivity
    blkConn = get_param(thisBlkName,'PortConnectivity');
    
    % and it's blocktype and masktype
    blkType = get_param(thisBlkName,'BlockType');
    blkMask = get_param(thisBlkName,'MaskType');
    
    % number of inputs and outputs
    numIn = 0;
    numOut = 0;
    
    % signal names
    inList = {};
    outList = {};
    
    % loop through to find outputs
    for jj=1:numel(blkConn),
        
        % fix oddity between struct and struct array
        if numel(blkConn)>1,
            thisPort = blkConn(jj);
        else
            thisPort = blkConn;
        end
        
        if ~isempty(thisPort.DstBlock),
            
            % this must be an output - add it to the signals list
            numOut = numOut+1;
            outList{numOut} = sprintf('%s_out%s',shortName, thisPort.Type);
            
        elseif ~isempty(thisPort.SrcBlock),
            
            % not connected if negative
            if thisPort.SrcBlock<0,
                error('Cannot translate: block has disconnected input.')
            end
            
            % this must be an input - trace it back
            srcBlkName = getfullname(thisPort.SrcBlock);
            srcShortName = ['s_' srcBlkName((2+numel(diagName)):end)];
            srcShortName(regexp(srcShortName,'\W'))='_';
            numIn = numIn+1;
            inList{numIn} = sprintf('%s_out%i',srcShortName, thisPort.SrcPort+1);
            
        end
        
    end
    
    % append latest outputs to list
    sigList = [sigList outList];
    
    % determine theories to apply
    theoryName = [];
    switch blkMask
        
        case 'Quadratic'
            
            theoryName = 'QuadraticBlock';
            
        case 'Subtract'
            
            theoryName = 'SubtractBlock';
            
        otherwise
            
            switch blkType
                
                case 'Sum'
                    
                    theoryName = 'AddBlock';
                    
                case 'UnitDelay'
                    
                    theoryName = 'DelayBlock';
                    
                case 'Constant'
                    
                    theoryName = 'ConstantBlock';
                    
                case 'Product'
                    
                    theoryName = 'MultiplyBlock';
                    
                case 'SubSystem'
                    
                    thyList = [thyList sprintf('(* Subsystem input port connections: %s *)', thisBlkName)];
                    % just pass through the inputs to the inports inside
                    for jj=1:numel(inList),
                        theory = sprintf('  axiom inport_conn_%s_%i: forall k : int. %s_In%i_out1 = %s', shortName, jj, shortName, jj, inList{jj});
                        thyList = [thyList theory];
                    end
                    
                    
                otherwise
                    
                    fprintf('Block not supported: %s (block %s)\n\n',blkType,thisBlkName)
                    
            end
            
    end
    
    % print some info
    if ~isempty(theoryName),
        theory = sprintf('  namespace import N_%s\n    clone export simulink.%s with ',shortName,theoryName);
        for jj=1:numel(inList),
            if jj>1,
                theory = [theory sprintf(', ')];
            end
            theory = [theory sprintf('function in%i = %s', jj, inList{jj})];
        end
        if (numel(inList)>0) && (numel(outList)>0),
            theory = [theory sprintf(', ')];
        end
        for jj=1:numel(outList),
            if jj>1,
                theory = [theory sprintf(', ')];
            end
            theory = [theory sprintf('function out%i = %s', jj, outList{jj})];
        end
        theory = [theory sprintf('\n  end\n')];
        thyList = [thyList theory];
    end
end

% write everything to a .why file
fid = fopen([diagName '.why'],'w');

% standard header
fprintf(fid,'theory MyModel\n\n  use import int.Int\n  use import matrix.Matrix\n\n');

% write the signal list
for ii=1:numel(sigList),
    fprintf(fid,'  function %s int : matrix\n\n',sigList{ii});
end

% write the theory cloning for each recognized block
for ii=1:numel(thyList),
    fprintf(fid,'\n\n%s',thyList{ii});
end

% hard-coded goal for now
fprintf(fid,'\n\ngoal G1: forall k : int. s_vdiff_an_out1 k = s_Vdiff_out1 k');

% end theory and close
fprintf(fid,'\n\nend\n');
fclose(fid);