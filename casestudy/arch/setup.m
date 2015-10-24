A = [0.8 0.3; 0 -0.6]
Q = diag([0.5 0.7])
P = dlyap(A',Q)
E = eig(P)

x0 = [1;1]

% deliberate screw-up
%P = dlyap(A,Q)
x0 = [1;-0.5]

% wrong A
%x0 = [1;0.5]

%x0 = [0;0]