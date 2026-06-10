% --- Setup ---
% Use the model name without the .slx extension
modelName = 'Faultdetectionusingwavelet'; 

% Define the range for Ground Resistance (Rg)
rg_values = 0.01:0.01:0.1; 

% Define the Fault Cases to simulate
% Format: {FaultA, FaultB, FaultC, Ground, "Label"}
cases = {
    'on',  'off', 'off', 'on',  "Single Line to Ground (A-G)";
    'on',  'on',  'off', 'off', "Line to Line (A-B)";
    'on',  'on',  'off', 'on',  "Double Line to Ground (AB-G)";
    'on',  'on',  'on',  'off', "Three Phase (ABC)";
    'on',  'on',  'on',  'on',  "Three Phase to Ground (ABC-G)"
};

% Initialize the Results Table
ResultsTable = table(); 

% Load the model into memory
if ~exist(modelName, 'file')
    error('The model file %s.slx was not found in the current directory.', modelName);
end
load_system(modelName);
faultBlock = [modelName '/Three-Phase Fault'];

% --- Main Simulation Loop ---
for c = 1:size(cases, 1)
    % 1. Set Fault Type for this Case
    set_param(faultBlock, 'FaultA', cases{c,1});
    set_param(faultBlock, 'FaultB', cases{c,2});
    set_param(faultBlock, 'FaultC', cases{c,3});
    set_param(faultBlock, 'GroundFault', cases{c,4});
    currentLabel = cases{c,5};
    
    fprintf('Starting simulations for: %s\n', currentLabel);

    for i = 1:length(rg_values)
        % 2. Update Ground Resistance (variable called in Simulink mask)
        Rg = rg_values(i);
        
        % 3. Run the Simulation
        sim(modelName); 
        
        % 4. Wavelet Processing (Fixing the indexing error)
        % Capture both outputs [C, L] for every run
        [cA, LA_cur] = wavedec(current1, 1, 'db4');
        [cB, LB_cur] = wavedec(current2, 1, 'db4');
        [cC, LC_cur] = wavedec(current3, 1, 'db4');
        [cG, LG_cur] = wavedec(current4, 1, 'db4');
        
        % Extract maximum detail coefficients
        m = max(detcoef(cA, LA_cur, 1));
        n = max(detcoef(cB, LB_cur, 1));
        p = max(detcoef(cC, LC_cur, 1));
        q = max(detcoef(cG, LG_cur, 1));
        
        % 5. Create Binary Triggers (1 if > 200, else 0)
        t = double(m > 200); 
        u = double(n > 200);
        v = double(p > 200);
        s = double(q > 200);
        
        % 6. Construct the new entry
        % Variable names must be consistent for every row
        newEntry = table(Rg, currentLabel, m, n, p, q, t, u, v, s, ...
            'VariableNames', {'Ground_Resistance', 'Diagnosis', 'm', 'n', 'p', 'q', 't', 'u', 'v', 's'});
        
        % 7. Append to the main table
        ResultsTable = [ResultsTable; newEntry];
    end
end

% --- Finalize ---
fprintf('\nAll simulations complete. Total Rows: %d\n', height(ResultsTable));

% Display result to Command Window
disp(ResultsTable);

% Optional: Save to Excel for your records
writetable(ResultsTable, 'Fault_Analysis_Results1.xlsx');