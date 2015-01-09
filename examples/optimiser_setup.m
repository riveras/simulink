A=[-1.5 -0.5;-0.5 -1.0];
B=[2; -1];
C=[1 0];
Q=C'*C;
R=[1];
[X,L,G] = dare(A,B,Q,R);
P=X;
K=G;



%Error sign of K
K=-K;

sys = ss((A-B*G),B,C,0,[]);
Wc = gram(sys,'o');


x0=[1;1];
x1=(A-B*K)*x0;