A1=[-0.5 0; 0 -0.5];
A2=[0.5 0; 0 0.5];
x0=[1;1];
setlmis([])
P=lmivar(1,[2 1]); %Symmetric P

% 1st LMI
lmiterm([1 1 1 P],A1',A1);
lmiterm([1 1 1 P],-1,1);

% 2nd LMI
lmiterm([2 1 1 P],A2',A2);
lmiterm([2 1 1 P],-1,1);

% P>0
lmiterm([-3 1 1 P],1,1);
lmiterm([3 1 1 0],0);

LMISYS = getlmis;

%lmiinfo(LMISYS)
c = mat2dec(LMISYS,eye(2));
%options = [0.00001]

[copt1,xopt1] = feasp(LMISYS);
newP1=dec2mat(LMISYS,xopt1,P);
%evlmi = evallmi(LMISYS,xopt1);
%[lhs,rhs] = showlmi(evlmi,1)
%eig(lhs-rhs)
%[lhs,rhs] = showlmi(evlmi,2)
%eig(lhs-rhs)
%[lhs,rhs] = showlmi(evlmi,3)
%eig(lhs-rhs)

[copt,xopt] = mincx(LMISYS,c);
newP=dec2mat(LMISYS,xopt,P);
%evlmi = evallmi(LMISYS,xopt);
%[lhs,rhs] = showlmi(evlmi,1)
%eig(lhs-rhs)
%[lhs,rhs] = showlmi(evlmi,2)
%eig(lhs-rhs)
%[lhs,rhs] = showlmi(evlmi,3)
%eig(lhs-rhs)