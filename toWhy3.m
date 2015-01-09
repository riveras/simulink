function toWhy3(model_name,type_check)
%% Libraries for the data structures
import java.util.List;

%% Importing the Simulink file 
load_system(model_name); %Opening the Simulink model
m_name=regexprep(model_name,'\W','_');
fileID = fopen(strcat(m_name,'.why'),'w'); %Open the Why3 file


%% Data structures (lists) used in the translator
global queueB;
queueB = java.util.LinkedList; %List of all blocks

global requires_b;
requires_b = java.util.LinkedList; %List of all the identified `Require' blocks -> parsed as verfication goals with Hoare triple structure
global preconditions;
preconditions = java.util.LinkedList; %List of blocks that give logical expressions for the verification goals (prec)
global postconditions;
postconditions = java.util.LinkedList; %List of blocks that give logical expressions for the verification goals (postc)

global goalblock;
goalblock = java.util.LinkedList; %List of all the identified `Goal' blocks -> parsed as simple goals 
global goals;
goals = java.util.LinkedList; %List of blocks that give logical expressions for goals

global numericalblock;
numericalblock = java.util.LinkedList;
global numericalcomp;
numericalcomp = java.util.LinkedList;

global subsys;
subsys = java.util.LinkedList; %List of `Subsystem' blocks (not in the Simulink library) in level 1
global subsys2;
subsys2 = java.util.LinkedList; %List of `Subsystem' blocks (not in the Simulink library) 
global oQueue; 
oQueue = java.util.LinkedList; %List with the blocks inside a Subsystem (with annotations)
global connectBlock;
connectBlock = java.util.LinkedList; %List of all the Subsystems related to the blocks with I/O connections (auxBlocks(i) belongs to connectBlock(i) subsystem)
global auxBlocks;
auxBlocks = java.util.LinkedList; %List of all the internal blocks in subsystem that have connections with inports/outports of the system

global inports;
inports = java.util.LinkedList; %List of the `Inport' blocks in a subsystem
global outports;
outports = java.util.LinkedList; % List of the `Outport' blocks in a subsystem
global enables;
enables = java.util.LinkedList; %List of the 'Enable' blocks in a subsystem

global parents;
parents = java.util.LinkedList; %List with information on the predecesors of the blocks (index = queueB or queueBlocks)
global children
children = java.util.LinkedList; %List with information on the successors of the blocks (index = queueB or queueBlocks)


global auxqueueB 
auxqueueB = java.util.LinkedList; %Auxiliar to eliminate specifications from other blocks

%% Opening the external libraries that will be needed for the translation
% Open and load contents of the library of blocks 
fileID2 = fopen('library_simulink.txt','r'); 
code_dic=textscan(fileID2,'%s','delimiter','\r');
all_text=code_dic{1};
fclose(fileID2);
for ix=1:1:size(all_text,1)
    all_signs=regexp(all_text{ix},'\\t');
    if ~isempty(all_signs)
        keys{ix}= all_text{ix}(1:all_signs(1)-1);
        texta{ix}= all_text{ix}(all_signs(1)+2:end);
    end
end

%% List of blocks in level 1 (highest level) of the model to start processing
startList();

%% Find any subsystem of type 3 or  enabled subsystem (type 4) in level 1
for i=0:1:queueB.size()-1
    handle=queueB.get(i); %Get first block in list
    b_blocktype=get_param(handle,'BlockType');%Type of block 
    if strcmp(b_blocktype,'SubSystem') %If the block is a subsystem, choose what action follows
        if (getType(handle)==3)||(getType(handle)==4) %Subsystem to be processed as a theory to keep modularity
            subsys.addLast(handle);
        end
    end
end

    %% Explore subsystems/enabled subsystems until no more subsystems and enabled subsystems (depth first)
    while subsys.size()>0
        handle_sb=subsys.removeFirst();
        subsys2.addLast(handle_sb); %Add to list of processed subsystems
        extractSs(handle_sb); %Interested in computing oQueue to find more subsystems type 3 or 4 (enabled subsystems)
        %visual_data(3);
        auxBlocks.clear(); %Not needed 
        connectBlock.clear(); %Not needed
        for i=0:1:oQueue.size()-1 %Explore oQueue
            type_ss=get_param(oQueue.get(i),'BlockType');
            if strcmp(type_ss,'SubSystem')
                if getType(oQueue.get(i))==3 || getType(oQueue.get(i))==4 
                    subsys.addFirst(oQueue.get(i));
                end
            end
        end
    end
    subsys=subsys2.clone(); %Keep backup for later

%% WITH TYPE CHECK%%
if type_check==1
    %% Compiling the model for dimensionality and data types
    eval([model_name,'([],[],[],''compile'');']);
    
    %% Process each subsystem, finding its specifications and using generic inputs/outputs
    for i=0:1:subsys2.size()-1
        my_handle=subsys2.removeLast();
        %Bring all the internal blocks
        auxBlocks.clear(); %Only interested in current subsystem
        connectBlock.clear(); %Only interested in current subsystem
        extractSs(my_handle); %Bring all the internal blocks of the subsystem again
        %Separate the verification goals on each theory for subsystems
        findAnnotations(); 
        %Put the blocks into a list, to compute its children/parents
        parents.clear();
        children.clear();
        for j=0:1:oQueue.size()-1
            if auxBlocks.indexOf(oQueue.get(j))>-1 %If the block is connected to inports/outports of the subsystem
                [tchildren,tparents]=bypassSs(oQueue.get(j));
            else
                [tchildren,tparents]=pred_and_suc(oQueue.get(j));
            end
            parents.addLast(tparents); %Add to main list
            children.addLast(tchildren); %Add to main list
        end
        % Generate the theory and add to library
        createSubsTheory(fileID,my_handle);
    end

    %% Finally add main theory that inherits all subsystems
    oQueue=queueB.clone();
    findAnnotations();
    %Compute predecessors and successors of blocks
    parents.clear();
    children.clear();
    for i=0:1:oQueue.size()-1
        [tchildren,tparents]=pred_and_suc(oQueue.get(i));
        parents.addLast(tparents);
        children.addLast(tchildren);
    end
    %Create theory
    createMainTheory(fileID,m_name);
    addGoals(fileID);  
    %Close theory
    fprintf(fileID,'end\n');
    %Close file
    fclose(fileID);
    %% Close compilation
    eval([model_name,'([],[],[],''term'');']);
else
    %% Process each subsystem, finding its specifications and using generic inputs/outputs
    for i=0:1:subsys2.size()-1
        my_handle=subsys2.removeLast();
        %Bring all the internal blocks
        auxBlocks.clear(); %Only interested in current subsystem
        connectBlock.clear(); %Only interested in current subsystem
        extractSs(my_handle); %Bring all the internal blocks of the subsystem again
        %Separate the verification goals on each theory for subsystems
        findAnnotations(); 
        %Put the blocks into a list, to compute its children/parents
        parents.clear();
        children.clear();
        for j=0:1:oQueue.size()-1
            if auxBlocks.indexOf(oQueue.get(j))>-1 %If the block is connected to inports/outports of the subsystem
                [tchildren,tparents]=bypassSs(oQueue.get(j));
            else
                [tchildren,tparents]=pred_and_suc(oQueue.get(j));
            end
            parents.addLast(tparents); %Add to main list
            children.addLast(tchildren); %Add to main list
        end
        % Generate the theory and add to library
        createSubsTheory(fileID,my_handle);
    end

    %% Finally add main theory that inherits all subsystems
    oQueue=queueB.clone();
    findAnnotations();
    %Compute predecessors and successors of blocks
    parents.clear();
    children.clear();
    for i=0:1:oQueue.size()-1
        [tchildren,tparents]=pred_and_suc(oQueue.get(i));
        parents.addLast(tparents);
        children.addLast(tchildren);
    end
    %Create theory
    createMainTheory(fileID,m_name);
    addGoals(fileID);  
    %Close theory
    fprintf(fileID,'end\n');
    %Close file
    fclose(fileID);
end


%% This function extracts the blocks in level 1 of the Simulink model, 
% appending them into a list, to start any further hierarchical inner analysis of subsystems or
% identification of annotations
function startList()
    open_blocks=find_system(model_name,'SearchDepth','1','LookUnderMasks','none','Type','block'); %The Simulink model is loaded into the workspace
    for ia=1:1:length(open_blocks) %The blocks are appended into queueB, and its level in the hierarchy is 1 (the top)
        b_handle=get_param(open_blocks(ia),'Handle');
        queueB.addLast(b_handle{1,1});
    end
end

%% Function to separate specification blocks 
function findAnnotations()
    limit1=oQueue.size();
    auxqueueB.clear();
    requires_b.clear();
    preconditions.clear();
    postconditions.clear();
    goalblock.clear();
    goals.clear();
    numericalblock.clear();
    numericalcomp.clear();
    %Remove require blocks
    for ii=0:1:limit1-1
        handle1= oQueue.removeFirst();
        bb_blocktype=get_param(handle1,'BlockType'); %Type of block for separation/processing
        if strcmp(bb_blocktype,'SubSystem') 
            mask1=get_param(handle1,'MaskType');
            b_mask1=char(mask1);
            b_portsq=get_param(handle1,'PortConnectivity'); %Extract pre and postcondition handles
            handlepreq=b_portsq(1,1).SrcBlock;
            if strcmp(b_mask1,'Require') %Eliminate require blocks from queue and mine pre and post condition blocks
                requires_b.addLast(handle1);
                handlepostq=b_portsq(2,1).SrcBlock;
                preconditions.addLast(handlepreq); %Put handles of precondition blocks in list
                postconditions.addLast(handlepostq); %Put handles of postcondition blocks in list
            elseif strcmp(b_mask1,'Goal')%Eliminate goal blocks
                goalblock.addLast(handle1);
                goals.addLast(handlepreq); %Put handles of precondition blocks in list
            elseif strcmp(b_mask1,'Numerical'); %Eliminate numerical computations
                numericalblock.addLast(handle1);
                numericalcomp.addLast(handlepreq); %Block for which an output needs to be processed
            else
                auxqueueB.addLast(handle1);
            end
        else
            auxqueueB.addLast(handle1);
        end
    end
    oQueue=auxqueueB.clone();
end  

%% Function to determine the type of subsystem, to decide its procedure
function type_num = getType(handle_bb)
    tb_mask=get_param(handle_bb,'MaskType');
    tb_ports=get_param(handle_bb,'Ports');
    tb_mask=char(tb_mask);
    %Type 1: from Simulink default library, treated as block
    if inSimList(tb_mask)==1
        type_num = 1;
    %Type 2: from my own library for control systems properties,
    %treated as block
    elseif inMyList(tb_mask)==1
        type_num = 2;
    %Type 3: grouped blocks, inner blocks need to be extracted
    elseif tb_ports(1,3)>0 %Enabled subsystem
        type_num = 4;
    else
        type_num = 3; %Normal subsystem
    end
end

%% Function to find if a subsystem is in the general Simulink library
function rettype = inSimList(the_mask)
    rettype = 0;
    %Bring my library of blocks
    for ipi=1:1:size(keys,2)
        if strcmp(the_mask,keys{ipi})
            rettype = 1;
        end
    end
end

%% Function to find if a subsystem is part of the OVL-like library
function rettype = inMyList(the_mask)
    rettype = 0;
    myList={'Require','Goal','Numerical'};
    for ipi=1:1:size(myList,2)
        if strcmp(the_mask,myList{ipi})
            rettype = 1;
        end
    end
end

%% Function to compute successors and predecessors of any block (except the ones that need bypassing)
function [pchildren,pparents]=pred_and_suc(handle_bb)
    pchildren=[];
    pparents=[];
    b_sizeports=get_param(handle_bb,'Ports'); %Extract the number of ports inputs and outputs
    sizeports=b_sizeports(1,1)+b_sizeports(1,2)+b_sizeports(1,3);
    b_ports=get_param(handle_bb,'PortConnectivity'); %Extract port handles
    %Process each port, successor or predecessor, or enable
    for i=1:1:sizeports
        b_type=b_ports(i,1).Type;
        if strcmp(b_type,'enable') %Identifying enable ports
            isdad=b_ports(i,1).SrcBlock; %Find predecessors of block i
            if isdad~=-1
                isdadp=b_ports(i,1).SrcPort;
                pparents=[pparents [isdad; isdadp+ones(size(isdadp));-1*ones(size(isdad))]]; %Append predecessor connected to enable (-1 port)
            end
        else %Not enable ports
            ischild=b_ports(i,1).DstBlock; %Find successors of block i
            isdad=b_ports(i,1).SrcBlock; %Find predecessors of block i
            if (isempty(isdad))  %The port is connected to successor 
                if ischild~=-1
                    ischildp=b_ports(i,1).DstPort;
                    pchildren=[pchildren [ischild; ischildp+ones(size(ischildp));str2num(b_type)*ones(size(ischild))]]; %Append successors
                end
            elseif (isempty(ischild)) %The port is connected to a predecessor
                if isdad~=-1
                    isdadp=b_ports(i,1).SrcPort;
                    pparents=[pparents [isdad; isdadp+ones(size(isdadp));str2num(b_type)*ones(size(isdad))]]; %Append predecessors
                end
            end
        end
    end
end

%% Function to connect inner blocks of subsystems to outer blocks, bypassing inports and outports
function [bchildren,bparents]=bypassSs(handle_bb)
    handle_ss=connectBlock.get(auxBlocks.indexOf(handle_bb));
    [bchildren,bparents]=pred_and_suc(handle_bb); %Compute connections of the block
    open_inports=find_system(handle_ss,'SearchDepth','1','LookUnderMasks','none','BlockType','Inport'); %Find all inports in subsystem
    open_outports=find_system(handle_ss,'SearchDepth','1','LookUnderMasks','none','BlockType','Outport'); %Find all outports in subsystem
    open_enables=find_system(handle_ss,'SearchDepth','1','LookUnderMasks','none','BlockType','EnablePort'); %Find all outports in subsystem
    
    %Check if block is connected to an outport
    for iz=1:1:size(bchildren,2)
        for jz=1:1:length(open_outports)
            if bchildren(1,iz)==open_outports(jz) %The destination block is an outport
                p_num= get_param(open_outports(jz),'Port');
                bchildren(:,iz)=[-20;str2num(p_num);bchildren(3,iz)];
            end
        end
    end
    %Check if block is connected to an inport
    for iz=1:1:size(bparents,2)
        for jz=1:1:length(open_inports)
            if bparents(1,iz)==open_inports(jz) %The destination block is an outport
                p_num= get_param(open_inports(jz),'Port');
                bparents(:,iz)=[-10;str2num(p_num);bparents(3,iz)];
            end
        end
    end
end

%% Extracting blocks of subsystem and adding them to main list to be processsed, changing their hierarchy
function extractSs(handle_ss)
    inports.clear();
    outports.clear();
    enables.clear();
    %Processing subsystems internally
    open_subblocks=find_system(handle_ss,'SearchDepth','1','LookUnderMasks','none','Type','block'); %Bring all blocks in immediate level of the subsystem
    open_inports=find_system(handle_ss,'SearchDepth','1','LookUnderMasks','none','BlockType','Inport'); %Find all inports in subsystem
    open_outports=find_system(handle_ss,'SearchDepth','1','LookUnderMasks','none','BlockType','Outport'); %Find all outports in subsystem
    open_enables=find_system(handle_ss,'SearchDepth','1','LookUnderMasks','none','BlockType','EnablePort'); %Find all outports in subsystem
    %Put inports in a list
    for ia=1:1:length(open_inports)
       i_handle=get_param(open_inports(ia),'Handle');
       inports.addLast(i_handle)
    end
    %Put outports in a list
    for ia=1:1:length(open_outports)
       o_handle=get_param(open_outports(ia),'Handle');
       outports.addLast(o_handle)
    end
    %Put enable ports in a list
    for ia=1:1:length(open_enables)
       o_handle=get_param(open_enables(ia),'Handle');
       enables.addLast(o_handle)
    end
    %Process all the blocks in subsystem into a list, minus inports and outports
    oQueue.clear();
    for ia=1:1:length(open_subblocks) 
        sbb_handle=get_param(open_subblocks(ia),'Handle');
        if not(round(sbb_handle)==round(handle_ss))&& not(inports.contains(sbb_handle))&& not(outports.contains(sbb_handle))&& not(enables.contains(sbb_handle))
            oQueue.addLast(sbb_handle);
        end
    end
    for ia=0:1:oQueue.size()-1 
        sp_handle=oQueue.get(ia);
        for ja=0:1:inports.size()-1 %Check if block is connected to inports
            i_handle=inports.get(ja);
            ports_i=get_param(i_handle,'PortConnectivity'); 
            for k=1:1:length(ports_i)
                all_suc=ports_i(k).DstBlock;
                for l=1:1:length(all_suc)
                    if sp_handle==all_suc(l)
                        if auxBlocks.indexOf(sp_handle)==-1
                            auxBlocks.addLast(sp_handle); %Add handles of blocks that need fixing in their I/o to a list
                            %auxBlocksIO.addLast('i'); %Indicate input
                            connectBlock.addLast(handle_ss); %Subsystem handle
                            
                        end
                    end
                end
            end
        end
        for ja=0:1:outports.size()-1 %Check if block is connected to outports
            o_handle=outports.get(ja);
            ports_o=get_param(o_handle,'PortConnectivity'); 
            for k=1:1:length(ports_o)
                all_par=ports_o(k).SrcBlock;
                for l=1:1:length(all_par)
                    if sp_handle==all_par(l)
                        if auxBlocks.indexOf(sp_handle)==-1
                            auxBlocks.addLast(sp_handle); %Add handles of blocks that need fixing in their I/o to a list
%                            auxBlocksIO.addLast('o'); %Indicate output
                            connectBlock.addLast(handle_ss); %Subsystem handle
                        end
                    end
                end
            end
        end
    end
end

%% Function to assemble the main theory in the Why3 file
function createMainTheory(fileID,the_name)
    fprintf(fileID,'theory M_%s\n',the_name); %Start the module with all the functions within the blocks to prove
    %Add relevant libraries
    fprintf(fileID,' use import int.Int\n'); %Open general libraries on integer numbers
    fprintf(fileID,' use import real.RealInfix\n');
    fprintf(fileID,' use import matrix.Matrix\n');
    fprintf(fileID,' use import bool.Bool\n');
    %Open and load contents of library of subsystems
    fileID4 = fopen('library_subsys.txt','r'); 
    code_dic2=textscan(fileID4,'%s','delimiter','\r');
    all_text2=code_dic2{1};
    fclose(fileID4);
    if ~isempty(all_text2)
        for iq=1:1:size(all_text2,1)
            all_signs2=regexp(all_text2{iq},'\\t');
            if ~isempty(all_signs2)
                keys2{iq}= all_text2{iq}(1:all_signs2(1)-1);
                texta2{iq}= all_text2{iq}(all_signs2(1)+2:end);
            end
        end
    end
      % celldisp(keys2);
     % celldisp(texta2);
    %Add all signals
    for ix=0:1:oQueue.size()-1
        gt_handle=oQueue.get(ix);
        %Name
        gt_name=lower(get_param(gt_handle,'Name'));
        gt_name=gt_name(~isspace(gt_name)); %Remove spaces of the name
        gt_name=regexprep(gt_name, '\W','_'); %Remove characters that are not in the Why3 syntax (leave a-z,_)
        gt_name=strcat('b_',gt_name);
        b_sizeports=get_param(gt_handle,'Ports');
        for jq=1:1:b_sizeports(1,2)
            st_name=strcat(gt_name,'_op',num2str(jq));
            if (preconditions.indexOf(gt_handle)==-1) && (postconditions.indexOf(gt_handle)==-1) && (goals.indexOf(gt_handle)==-1)
                fprintf(fileID,' function %s int: matrix\n',st_name);
            else
                g_type = get_param(gt_handle,'BlockType');
                if strcmp(g_type,'SubSystem') 
                    mask=get_param(gt_handle,'MaskType');
                    g_type=mask;
                end
                if strcmp(g_type,'Compare To Zero')||strcmp(g_type,'Logic')||strcmp(g_type,'Compare To Constant')||strcmp(g_type,'Detect Decrease')||strcmp(g_type,'Detect Increase')||strcmp(g_type,'RelationalOperator')
                    fprintf(fileID,' function %s int: bool\n',st_name);
                elseif (preconditions.indexOf(gt_handle)~=-1) || (postconditions.indexOf(gt_handle)~=-1) || (goals.indexOf(gt_handle)~=-1)
                    fprintf(fileID,' function %s int: bool\n',st_name);
                else
                    fprintf(fileID,' function %s int: matrix\n',st_name);
                end
            end
        end
    end
    fprintf(fileID,'\n');
    %The theories  
    for ix=0:1:oQueue.size()-1
        gt_handle=oQueue.get(ix);
        all_parts={};
        % Add cloned theories and parameters
        if subsys.indexOf(gt_handle)>-1 % If subsystem (in library)
            g_type=get_param(gt_handle,'Name'); %Get the name
            g_type=g_type(~isspace(g_type));
            g_type=regexprep(g_type, '\W','_');
            g_type(1,1)=upper(g_type(1,1));
            g_type=strcat('M_',g_type);
            if ~isempty(all_text2)
                %Extract all the translation
                for jw=1:1:size(keys2,2)
                    dic_type=keys2{jw};
                    if strcmp(g_type,dic_type) %Found the block in the library, extract translation
                        all_signs=regexp(texta2{jw},'<<...>>');
                        if ~isempty(all_signs)
                            if all_signs(1)~=1
                                all_parts=[all_parts;texta2{jw}(1:all_signs(1,1)-1)];
                            end
                            for k=1:1:size(all_signs,2)-1
                                all_parts=[all_parts;texta2{jw}(all_signs(k)+7:all_signs(k+1)-1)];
                            end
                            all_parts=[all_parts;texta2{jw}(all_signs(size(all_signs,2))+7:end)];
                        else
                            all_parts=texta2{jw};
                        end
                        for k=1:1:size(all_parts,1) %Print text and parameters
                            to_print=get_the_data(all_parts{k},gt_handle);
                            if strcmp(to_print,'')
                                if k<size(all_parts,1)
                                    to_print2=get_the_data(all_parts{k+1},gt_handle);
                                    if ~strcmp(to_print2,'empty')
                                        fprintf(fileID,all_parts{k});
                                    end
                                end
                            elseif ~strcmp(to_print,'empty')
                                fprintf(fileID,'%s',to_print);
                            end
                        end
                        fprintf(fileID,'\n');
                    end
                end
            end
        else % If normal block
            g_type=get_param(gt_handle,'BlockType'); %Type of block
            %If subsystem then compare the mask
            if strcmp(g_type,'SubSystem') 
                mask=get_param(gt_handle,'MaskType');
                g_type=mask;
            end
            for jx=1:1:size(keys,2) %Check it exists in the blocks library
                dic_type=keys{jx};
                if strcmp(g_type,dic_type) %Found the block in the library, extract translation
                    all_signs=regexp(texta{jx},'<<...>>');
                    if ~isempty(all_signs)
                        if all_signs(1)~=1
                            all_parts=[all_parts;texta{jx}(1:all_signs(1,1)-1)];
                        end
                        for k=1:1:size(all_signs,2)-1
                            all_parts=[all_parts;texta{jx}(all_signs(k)+7:all_signs(k+1)-1)];
                        end
                        all_parts=[all_parts;texta{jx}(all_signs(size(all_signs,2))+7:end)];
                    else
                        all_parts=texta{jx};
                    end
                    for k=1:1:size(all_parts,1) %Print text and parameters
                        to_print=get_the_data(all_parts{k},gt_handle);
                        if strcmp(to_print,'')
                             if k<size(all_parts,1)
                                to_print2=get_the_data(all_parts{k+1},gt_handle);
                                if ~strcmp(to_print2,'empty')
                                    fprintf(fileID,all_parts{k});
                                end
                            end
                        elseif ~strcmp(to_print,'empty')
                            fprintf(fileID,'%s',to_print);
                        end
                    end
                    fprintf(fileID,'\n');
                end
            end
        end
        fprintf(fileID,'\n');
    end
end

%% Function to assemble a theory in the Why3 file, for subsystems and enabled subsystems
function createSubsTheory(fileID,handle_ss)
    handles_all=[]; %All handles of blocks into the theory
    for iq=0:1:oQueue.size()-1
        handles_all=[handles_all oQueue.get(iq)];
    end      
    % Start the theory
    th_name=get_param(handle_ss,'Name'); %Get the name
    th_name=th_name(~isspace(th_name));
    th_name=regexprep(th_name, '\W','_');
    th_name(1,1)=upper(th_name(1,1));
    fprintf(fileID,'theory M_%s\n',th_name); %Start the module with all the functions within the blocks to prove
    %Add relevant libraries
    fprintf(fileID,' use import int.Int\n');
    fprintf(fileID,' use import real.RealInfix\n');
    fprintf(fileID,' use import bool.Bool\n'); %Open general libraries on booleans 
    fprintf(fileID,' use import matrix.Matrix\n');%Open general library for vectors
    % Write all the signal names
    for iq=1:1:size(handles_all,2)
        gt_handle=handles_all(1,iq);
        %Name
        gt_name=lower(get_param(gt_handle,'Name'));
        gt_name=gt_name(~isspace(gt_name)); %Remove spaces of the name
        gt_name=regexprep(gt_name, '\W','_'); %Remove characters that are not in the Why3 syntax (leave a-z,_)
        gt_name=strcat('b_',gt_name);
        b_sizeports=get_param(gt_handle,'Ports');
        for jq=1:1:b_sizeports(1,2)
            st_name=strcat(gt_name,'_op',num2str(jq));
            if (preconditions.indexOf(gt_handle)==-1) && (postconditions.indexOf(gt_handle)==-1) && (goals.indexOf(gt_handle)==-1)
                fprintf(fileID,' function %s int: matrix\n',st_name);
            else
                g_type = get_param(gt_handle,'BlockType');
                if strcmp(g_type,'SubSystem') 
                    mask=get_param(gt_handle,'MaskType');
                    g_type=mask;
                end
                if strcmp(g_type,'Compare To Zero')||strcmp(g_type,'Logic')||strcmp(g_type,'Compare To Constant')||strcmp(g_type,'Detect Decrease')||strcmp(g_type,'Detect Increase')||strcmp(g_type,'RelationalOperator')
                    fprintf(fileID,' function %s int: bool\n',st_name);
                elseif (preconditions.indexOf(gt_handle)~=-1) || (postconditions.indexOf(gt_handle)~=-1) || (goals.indexOf(gt_handle)~=-1)
                    fprintf(fileID,' function %s int: bool\n',st_name);
                else
                    fprintf(fileID,' function %s int: matrix\n',st_name);
                end
            end
        end
    end
    % Add generic inputs and outputs
    % Use auxBlocks (blocks that are connected to I/O of subsystems and connectBlock (subsystem)
    ss_sizeports=get_param(handle_ss,'Ports'); %Generic inputs
    for jq=1:1:ss_sizeports(1,1)
        stt_type='matrix'; %Default value
        for k=0:1:auxBlocks.size()-1
            ch_dad=parents.get(oQueue.indexOf(auxBlocks.get(k)));
            for l=1:1:size(ch_dad,2)
                if ch_dad(1,l)==-10 && ch_dad(2,l)==jq %The block is connected to inport
                    sttt_type=get_param(auxBlocks.get(k),'BlockType');
                    if strcmp(sttt_type,'Logic')
                        stt_type='bool';
                    end
                end
            end
        end
        fprintf(fileID,' function in%d int: %s\n',jq,stt_type); 
    end

    for jq=1:1:ss_sizeports(1,2) %Generic outputs
        %Check children and determine if they are boolean or matrix
        for k=0:1:auxBlocks.size()-1
            ch_child=children.get(oQueue.indexOf(auxBlocks.get(k)));
            for l=1:1:size(ch_child,2)
                if ch_child(1,l)==-20 && ch_child(2,l)==jq %The block is connected to outport
                    gth_type=get_param(auxBlocks.get(k),'BlockType');
                    if strcmp(gth_type,'SubSystem')
                        mask=get_param(auxBlocks.get(k),'MaskType');
                        gth_type=mask;
                    end
                    if strcmp(gth_type,'Logic')
                        s_type='bool';
                    else
                        s_type='matrix';
                    end
                end
            end
        end
        fprintf(fileID,' function out%d int: %s\n',jq,s_type);
        
    end
    for jq=1:1:ss_sizeports(1,3) %Enabled input ports
        %Find the type of the inner block connected to inport
        fprintf(fileID,' function en%d int: bool\n',jq); 
    end
    %Find the type of outports and add axioms for matching signals with
    %inner blocks
    for jq=1:1:ss_sizeports(1,2) %Axioms to link signals of inner blocks to Outports
        for k=0:1:auxBlocks.size()-1
            ch_child=children.get(oQueue.indexOf(auxBlocks.get(k)));
            for l=1:1:size(ch_child,2)
                if ch_child(1,l)==-20 && ch_child(2,l)==jq %The block is connected to outport
                    gth_name=lower(get_param(auxBlocks.get(k),'Name'));
                    gth_name=gth_name(~isspace(gth_name));
                    gth_name=regexprep(gth_name, '\W','_'); %Remove characters that are not in the Why3 syntax (leave a-z,_)
                    gth_name=strcat('b_',gth_name);
                    gth_name=strcat(gth_name,'_op',num2str(ch_child(3,l)));
                end
            end
        end
        fprintf(fileID,' axiom v%d: forall k: int. out%d k = %s k\n',jq,jq,gth_name);
    end

    % Open and load contents of the library of subsystems theories
    fileID4 = fopen('library_subsys.txt','r'); 
    code_dic2=textscan(fileID4,'%s','delimiter','\r');
    all_text2=code_dic2{1};
    fclose(fileID4);
    if ~isempty(all_text2)
        for iq=1:1:size(all_text2,1)
            all_signs2=regexp(all_text2{iq},'\\t');
            if ~isempty(all_signs2)
                keys2{iq}= all_text2{iq}(1:all_signs2(1)-1);
                texta2{iq}= all_text2{iq}(all_signs2(1)+2:end);
            end
        end
    end
%       celldisp(keys2);
%       celldisp(texta2);
    fprintf(fileID,'\n');
    % Clone theories of all blocks
    for iq=1:1:size(handles_all,2)
        all_parts={};
        if subsys.indexOf(handles_all(1,iq))>-1 % If subsystem (in library)
            g_type=get_param(handles_all(1,iq),'Name'); %Get the name
            g_type=g_type(~isspace(g_type));
            g_type=regexprep(g_type, '\W','_'); %Remove characters that are not in the Why3 syntax (leave a-z,_)
            g_type(1,1)=upper(g_type(1,1));
            g_type=strcat('M_',g_type);
            if ~isempty(all_text2)
                %Extract all the translation
                for jw=1:1:size(keys2,2)
                    dic_type=keys2{jw};
                    if strcmp(g_type,dic_type) %Found the block in the library, extract translation
                        all_signs=regexp(texta2{jw},'<<...>>');
                        if ~isempty(all_signs)
                            if all_signs(1)~=1
                                all_parts=[all_parts;texta2{jw}(1:all_signs(1,1)-1)];
                            end
                            for k=1:1:size(all_signs,2)-1
                                all_parts=[all_parts;texta2{jw}(all_signs(k)+7:all_signs(k+1)-1)];
                            end
                            all_parts=[all_parts;texta2{jw}(all_signs(size(all_signs,2))+7:end)];
                        else
                            all_parts=texta2{jw};
                        end
                        for k=1:1:size(all_parts,1) %Print text and parameters
                            to_print=get_the_data(all_parts{k},handles_all(iq));
                            if strcmp(to_print,'')
                                 if k<size(all_parts,1)
                                    to_print2=get_the_data(all_parts{k+1},handles_all(iq));
                                    if ~strcmp(to_print2,'empty')
                                        fprintf(fileID,all_parts{k});
                                    end
                                end
                            elseif ~strcmp(to_print,'empty')
                                fprintf(fileID,'%s',to_print);
                            end
                        end
                        fprintf(fileID,'\n');
                    end
                end
            end
        else % If normal block
            g_type=get_param(handles_all(1,iq),'BlockType'); %Type of block
            %If subsystem then compare the mask
            if strcmp(g_type,'SubSystem') 
                mask=get_param(handles_all(1,iq),'MaskType');
                g_type=mask;
            end
            %Extract all the translation
            for jw=1:1:size(keys,2)%For blocks in the library
                dic_type=keys{jw};
                if strcmp(g_type,dic_type) %Found the block in the library, extract translation
                    all_signs=regexp(texta{jw},'<<...>>');
                    if ~isempty(all_signs)
                        if all_signs(1)~=1
                            all_parts=[all_parts;texta{jw}(1:all_signs(1,1)-1)];
                        end
                        for k=1:1:size(all_signs,2)-1
                            all_parts=[all_parts;texta{jw}(all_signs(k)+7:all_signs(k+1)-1)];
                        end
                        all_parts=[all_parts;texta{jw}(all_signs(size(all_signs,2))+7:end)];
                    else
                        all_parts=texta{jw};
                    end
                    for k=1:1:size(all_parts,1) %Print text and parameters
                        to_print=get_the_data(all_parts{k},handles_all(iq));
                        if strcmp(to_print,'')
                            if k<size(all_parts,1)
                                to_print2=get_the_data(all_parts{k+1},handles_all(iq));
                                if ~strcmp(to_print2,'empty')
                                    fprintf(fileID,all_parts{k});
                                end
                            end
                        elseif ~strcmp(to_print,'empty')
                            fprintf(fileID,'%s',to_print);
                        end
                    end
                    fprintf(fileID,'\n');
                end
            end
        end
         fprintf(fileID,'\n');
    end
    % Add goals
    addGoals(fileID);  
    % If the subsystem is Enabled 
    for iq=1:1:ss_sizeports(1,3)
        for jq=1:1:ss_sizeports(1,2)
            fprintf(fileID,'  axiom enabled%d: forall k: int. en%d k = False <-> out%d k = 0.0\n',iq,iq,jq);
        end
    end
    %Close theory
    fprintf(fileID,'end\n');
    %Find if the theory has not been written yet before appending
    repeated=0;
    if ~isempty(all_text2)
        for jw=1:1:size(keys2,2)
            dic_type=keys2{jw};
            if strcmp(dic_type,strcat('M_',th_name))
                repeated=1;
            end
        end
    end
    %Write theory to library
    if repeated==0
        fileID2 = fopen('library_subsys.txt','a'); 
        fprintf(fileID2,'M_%s\\t  clone M_%s as <<...>>Name_block<<...>> with ',th_name,th_name);
        %Add the input functions
        for iq=1:1:ss_sizeports(1,1)
            if iq==1
                fprintf(fileID2,'function in%d = <<...>>input%d<<...>>',iq,iq);
            else
                fprintf(fileID2,', function in%d = <<...>>input%d<<...>>',iq,iq);
            end
        end
        %Add the enable input functions
        for iq=1:1:ss_sizeports(1,3)
            fprintf(fileID2,', function en%d = <<...>>enable%d<<...>>',iq,iq);
        end
        %Add the output functions
        for iq=1:1:ss_sizeports(1,2)
            fprintf(fileID2,', function out%d = <<...>>output%d<<...>>',iq,iq);
        end
        fprintf(fileID2,'\\n\\t \r\n');
        fclose(fileID2);
    end
end

%% Function to add axioms and verification goals in the Why3 file
function addGoals(fileID)
    for is=0:1:goalblock.size()-1
        gb_handle=goalblock.get(is); %add name of the block
        gb_name=lower(get_param(gb_handle,'Name'));
        gb_name=gb_name(~isspace(gb_name));
        gb_name=regexprep(gb_name,'\W','_');
        gb_name=strcat('b_',gb_name);
        fprintf(fileID,' goal GG%d%s : forall k: int. ',is+1,gb_name);
        gp_handle=goals.get(is);
        gp_name=lower(get_param(gp_handle,'Name'));
        gp_name=gp_name(~isspace(gp_name)); %Remove spaces of the name
        gp_name=regexprep(gp_name, '\W','_'); %Remove characters that are not in the Why3 syntax (leave a-z,_)
        gp_name=strcat('b_',gp_name);
        [ppchildren,ppparents]=pred_and_suc(gp_handle);
        for jj=1:1:size(ppchildren,2)
            if ppchildren(1,jj)==goalblock.get(is)
                fprintf(fileID,'%s_op%d k = True\n',gp_name,ppchildren(3,jj));
            end
        end
         fprintf(fileID,'\n');
    end
    for is=0:1:requires_b.size()-1
        %Begin goal following requires_b names
        gb_handle=requires_b.get(is); %add name of the block
        gb_name=lower(get_param(gb_handle,'Name'));
        gb_name=gb_name(~isspace(gb_name));
        gb_name=regexprep(gb_name,'\W','_');
        gb_name=strcat('b_',gb_name);
        fprintf(fileID,'  goal G%d%s : forall k: int. ',is+1,gb_name);
        %Precondition
        gp_handle=preconditions.get(is);
        gp_name=lower(get_param(gp_handle,'Name'));
        gp_name=gp_name(~isspace(gp_name)); %Remove spaces of the name
        gp_name=regexprep(gp_name, '\W','_'); %Remove characters that are not in the Why3 syntax (leave a-z,_)
        gp_name=strcat('b_',gp_name);
        [ppchildren,ppparents]=pred_and_suc(gp_handle);
        for jj=1:1:size(ppchildren,2)
            if ppchildren(1,jj)==requires_b.get(is)
                fprintf(fileID,'%s_op%d k = True',gp_name,ppchildren(3,jj));
            end
        end
        fprintf(fileID,' <-> ');
        %Postcondition
        pg_handle=postconditions.get(is);
        gp_name=lower(get_param(pg_handle,'Name'));
        gp_name=gp_name(~isspace(gp_name)); %Remove spaces of the name
        gp_name=regexprep(gp_name, '\W','_'); %Remove characters that are not in the Why3 syntax (leave a-z,_)
        gp_name=strcat('b_',gp_name);
        [ppchildren,ppparents]=pred_and_suc(pg_handle);
        for jj=1:1:size(ppchildren,2)
            if ppchildren(1,jj)==requires_b.get(is)
                fprintf(fileID,'%s_op%d k = True\n',gp_name,ppchildren(3,jj));
            end
        end
        fprintf(fileID,'\n');
    end
end

%% Function that converts parameters in the translation from library to the Why3 file
function string_to_put = get_the_data(requested,handle_bb)
    %Name of the block for functions(representing the signals)
    out_name=lower(get_param(handle_bb,'Name')); %Name of the current block
    out_name=out_name(~isspace(out_name)); %Remove spaces of the name
    out_name=regexprep(out_name, '\W','_'); %Remove characters that are not in the Why3 syntax (leave a-z,_)
    pred_b=parents.get(oQueue.indexOf(handle_bb));
    succ_b=children.get(oQueue.indexOf(handle_bb));
    %If requested is inputX, outputX or enabledX convert to generic + no.
    no_port_q=0;
    ch_select=regexp(requested,'input','ONCE');
    if ~isempty(ch_select)
        no_port_q=requested(6);
        requested='input';
    end
    ch_select=regexp(requested,'output','ONCE');
    if ~isempty(ch_select)
        no_port_q=requested(7);
        requested='output';
    end
    ch_select=regexp(requested,'enable','ONCE');
    if ~isempty(ch_select)
        no_port_q=requested(7);
        requested='enable';
    end
    switch requested
        case 'name_block'
            string_to_put=out_name;
        case 'Name_block'
            %Name of the block to clone the theory/add axioms
            other_name=out_name;
            other_name(1,1)=upper(other_name(1,1));
            other_name=strcat('B_',other_name);
            string_to_put=other_name;
        case 'input'
            string_to_put='empty'; %Default
            if isempty(pred_b)
                string_to_put='empty'; %Default
            else
                for iz=1:1:size(pred_b,2) %Find the predecessor connected to that port of the block
                    if pred_b(3,iz)==str2num(no_port_q)
                        if pred_b(1,iz)==-10
                            string_to_put=strcat('in',num2str(pred_b(2,iz))); %Name of first input
                        else
                            inp1_name=lower(get_param(pred_b(1,iz),'Name')); %First input
                            inp1_name=inp1_name(~isspace(inp1_name));
                            inp1_name=regexprep(inp1_name,'\W','_');
                            inp1_name=strcat('b_',inp1_name);
                            string_to_put=strcat(inp1_name,'_op',num2str(pred_b(2,iz))); %Name of first input
                        end
                    end
                    
                end    
            end
        case 'output'
            string_to_put='empty'; %Default
            if ~isempty(succ_b)
                out_name=strcat('b_',out_name);
                string_to_put=strcat(out_name,'_op',num2str(no_port_q)); %Name of the output of the block
            end
        case 'enable'
            string_to_put='empty'; %Default
            if isempty(pred_b)
                string_to_put='empty'; %Default
            else
                for iz=1:1:size(pred_b,2) %Find the successor connected to that port of the block
                    if pred_b(3,iz)==-1
                        inp1_name=lower(get_param(pred_b(1,iz),'Name')); %First input
                        inp1_name=inp1_name(~isspace(inp1_name));
                        inp1_name=regexprep(inp1_name,'\W','_');
                        inp1_name=strcat('b_',inp1_name);
                        string_to_put=strcat(inp1_name,'_op',num2str(pred_b(2,iz))); %Name of first input
                    end
                end    
            end
        case 'gain_value'
            gain_v=get_param(handle_bb,'Gain'); %Name of the current block
            num_gain=str2double(gain_v);
            if num_gain<0
                string_to_put=strcat('-.',num2str(abs(num_gain),'%f'));
            else
                string_to_put=num2str(abs(num_gain),'%f');
            end
        case 'sign_type_ctz'
            relop_b=get_param(handle_bb,'relop');
            switch relop_b
                case '=='
                    string_to_put='eq';
                case '>'
                    string_to_put='g';
                case '~='
                    string_to_put='neq';
                case '<'
                    string_to_put='l';
                case '<='
                    string_to_put='le';
                case '>='
                    string_to_put='ge';
            end
        case 'sign_type_rel'
            op = get_param(handle_bb,'Operator');
            switch op
                case '=='
                    string_to_put='eq';
                case '>'
                    string_to_put='g';
                case '~='
                    string_to_put='neq';
                case '<'
                    string_to_put='l';
                case '<='
                    string_to_put='le';
                case '>='
                    string_to_put='ge';
            end
        case 'Block_type'
            po_type=get_param(handle_bb,'BlockType');
            if strcmp(po_type,'SubSystem') 
                po_mask=get_param(handle_bb,'MaskType');
                po_type=char(po_mask);
            end
            po_type=po_type(~isspace(po_type));
            string_to_put=po_type;
        case 'sum_type'
            val_b=get_param(handle_bb,'Inputs');
            if strcmp(val_b,'+-')
               string_to_put='subtract'; 
            else
               string_to_put='add';
            end
        case 'goto_find' %For the axiom that relates from to goto block
            goto_name='';
            %The tag of the `From' block
            from_tag=get_param(handle_bb,'GotoTag');
            %Find all goto blocks in the entire model
            open_gotos=find_system(model_name,'LookUnderMasks','none','BlockType','Goto');
            %Find the goto block that matches the from block, 'GotoTag'
            for iaa=1:1:length(open_gotos)
                goto_handle=get_param(open_gotos(iaa),'Handle');
                ggg_tag=get_param(goto_handle{1,1},'GotoTag');
                if strcmp(ggg_tag,from_tag)
                    pred_bgt=parents.get(oQueue.indexOf(goto_handle{1,1}));
                    ggg_name=lower(get_param(pred_bgt(1,1),'Name')); %Name of the current block
                    ggg_name=ggg_name(~isspace(ggg_name)); %Remove spaces of the name
                    ggg_name=regexprep(ggg_name, '\W','_'); %Remove characters that are not in the Why3 syntax (leave a-z,_)
                    ggg_name=strcat('b_',ggg_name,'_op',num2str(pred_bgt(2,1)));
                    break;
                end
            end
            %Bring the name of the block
            string_to_put=ggg_name;
        case 'VH'
            string_to_put='';
            th_mode=get_param(handle_bb,'Mode');
            if strcmp(th_mode,'Multidimensional array') || strcmp (th_mode,'Vector')
               th_dim=get_param(handle_bb,'ConcatenateDimension');
               if strcmp(th_dim,'') || strcmp(th_dim,'1')
                   string_to_put='V';
               else
                   string_to_put='H';
               end
                   
            end
        case 'minormax'
            string_to_put='';
            minormaxchoice= get_param(handle_bb,'Function');
            if strcmp(minormaxchoice,'min')
                string_to_put='min';
            else
                string_to_put='max';
            end
        otherwise
            string_to_put='';
    end
end %Get the parameter to complete the code lines for the Why3 file

end