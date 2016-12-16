function [C_wa, Total_Rebalancing_Miles] = VehicleReblancing(N)
%% ---Generate Graph---
rand('twister',1);
Num_V = 10;
E_H = triu(Num_V,1);
E_H = E_H + E_H';

Triptime=[];
RangeBound = 10;
Location = RangeBound*rand(2,Num_V);
for i = 1:Num_V
    for j = 1:Num_V
        Triptime(i,j) = norm(Location(:,i)-Location(:,j));
    end
end
G = graph(Triptime);


%% ---Parameters---
rand('twister',2);
rand_num = rand(1,Num_V);
lamda_i = rand_num; %Arrival rate
lamda_i_j = []; %Transition rate
prob_i_j = [];

for i = 1:Num_V
    for j = 1:Num_V
        if i~=j
            rand('twister',3);
            lamda_i_j(i,j) = lamda_i(i)*rand();
            prob_i_j(i,j) = lamda_i(j)/(sum(lamda_i)-lamda_i(i));
        else
            lamda_i_j(i,j)=0;
        end
    end
end

q_i = zeros(1,Num_V); %Demand queue

t_max = 20; %customer waiting budget
C_wa = 0; %total number of walk-aways
Total_Rebalancing_Miles = 0;
Run = 0;
Stay = 0;
%N = 100; %fleet size
v_i = N*ones(1,Num_V)/Num_V; %number of taxi parked at each hub
v_i_j = zeros(Num_V,Num_V); %number of taxi en route from hub i to j


%% ---Simulation---
t = 0; %Initial time
Total_T = 100; %Time of simulation
delta_t = 1; %Step size
BalancingTime = 3; %Time between two balancing
Num_Balancing = 0;
Data = {};

TaxiTrip = cell(Num_V);
TaxiTrip(:,:) = {[0;Inf]};%[# of the batch of taxis, time to arrive] for taxis goes from hub i to j
TaxiRebalance = cell(Num_V);
TaxiRebalance(:,:) = {[0;Inf]};
CustWaiting = cell([1,Num_V]);
CustWaiting(:) = {[0;0]};

while t < Total_T
    
    
rand_num = rand(1,Num_V);
rand_num2 = rand(Num_V,Num_V);

lamda_i = rand_num; %Arrival rate
lamda_i_j = []; %Transition rate
prob_i_j = [];

for ii = 1:Num_V
    for jj = 1:Num_V
        if ii~=jj
            lamda_i_j(ii,jj) = lamda_i(ii)*rand();
            prob_i_j(ii,jj) = rand_num2(ii,jj)/sum(rand_num2(ii,:)-rand_num2(ii,ii));
        else
            lamda_i_j(ii,jj)=0;
        end
    end
end



    for i = 1:Num_V
        index0 = CustWaiting{i}(2,:)>=t_max;
        C_wa = C_wa + sum(CustWaiting{i}(1,index0)); %number of walk-aways
        CustWaiting{i} = [CustWaiting{i}(1,~index0); CustWaiting{i}(2,~index0) + delta_t];
        CustWaiting{i} = [CustWaiting{i},[lamda_i(i)*delta_t;0]];
        % # of reneging = sum(CustWaiting{i}(1,index0));
        arrival_i = 0;
        for j = 1:Num_V
            if i~=j
                index1 = TaxiTrip{j,i}(2,:)<=t;
                index2 = TaxiRebalance{j,i}(2,:)<=t;
                arrival_j_i = sum(TaxiTrip{j,i}(1,index1)) + sum(TaxiRebalance{j,i}(1,index2));
                arrival_i = arrival_i + arrival_j_i;
                TaxiTrip{j,i} = TaxiTrip{j,i}(:,~index1);
                TaxiRebalance{j,i} = TaxiRebalance{j,i}(:,~index2);
                v_i_j(j,i) = v_i_j(j,i) - arrival_j_i;
            end
        end
        
        v_i(i) = arrival_i+v_i(i);
        q_i(i) = sum(CustWaiting{i}(1,:));
        depart_i = min(v_i(i),q_i(i));
        v_i(i) = v_i(i)- depart_i;
        
        while depart_i > 0
            index3 = CustWaiting{i}(2,:) == max(CustWaiting{i}(2,:));
            depart_i = depart_i - min(depart_i, sum(CustWaiting{i}(1,index3)));
            if depart_i >= sum(CustWaiting{i}(1,index3))
                CustWaiting{i} = CustWaiting{i}(:,~index3);
            else
                CustWaiting{i}(:,index3) = CustWaiting{i}(:,index3) - [depart_i/nnz(index3);0];
            end
        end
        
        for j = 1:Num_V
            if i~=j
                TaxiTrip{i,j} = [TaxiTrip{i,j}, [depart_i*prob_i_j(i,j);t+Triptime(i,j)]];
                v_i_j(i,j) = v_i_j(i,j) + depart_i*prob_i_j(i,j);
            end        
        end
    end
    
    X = zeros(Num_V,Num_V);
    if abs(t - BalancingTime*(Num_Balancing+1)) < 0.0001
        n_exc = v_i + ones(1,Num_V)*v_i_j;
        m = sum(n_exc);
        Q = sum(q_i);
        if Q <= m
            %n_des = q_i; % feedback rebalancing
            n_des = q_i + lamda_i/sum(lamda_i) * (m-Q); % feedback + proportional predictive rebalancing
        else
            n_des = q_i*m/Q;
        end
        X = Opt(Num_V,Triptime,n_des,n_exc);
        Num_Balancing = Num_Balancing+1;
        Total_Rebalancing_Miles = Total_Rebalancing_Miles + sum(sum(triu(X,1)+triu(X,-1)));
    end
        
    for i = 1:Num_V
        for j = 1:Num_V
            if i~=j
                TaxiRebalance{i,j} = [TaxiRebalance{i,j}, [X(i,j);t+Triptime(i,j)]];
            end
        end
    end
    
    t = t + delta_t;
end

% C_wa
end       
        
        
        
        
        
        
        
        
        
        
        
        
        
