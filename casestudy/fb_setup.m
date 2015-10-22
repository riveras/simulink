A = [-1.5 -0.5; -0.5 -1]
B = [2;-1]
F = [2.01 1.32]
P = dlyap((A+B*F)',eye(2))
E = eig(P)

x0 = [1;1]

% deliberate screw-up
Pwrong = dlyap((A+B*F),eye(2))
%x0 = [1;-0.8]

% E2 - switch control
%F = -F

% E3 - wrong P
%P = Pwrong

% E7 - gain matrix
G = 0.8*eye(2)