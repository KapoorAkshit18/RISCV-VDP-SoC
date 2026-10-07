%% Mutation Testing — Publication-Quality Figures
% Source: mutation_results_temp.csv  (M01-M10 SoC interconnect, M_TPU_01-05 TPU)
%
% Matrix coding:
%   0 = escaped / unobservable
%   1 = detected
%   2 = equivalent mutant (excluded from viable-mutation denominator)
%
% Equivalent mutants:
%   SoC:  M05 (vdp_write ignored by slave), M09 (RAM addr[1:0] always 00)
%   TPU:  none

clear; clc; close all;

% =========================================================================
%  SHARED PALETTE
% =========================================================================
COL_ESCAPED    = [0.94 0.94 0.94];   % light gray
COL_DETECTED   = [0.25 0.55 0.55];   % muted teal
COL_EQUIVALENT = [0.90 0.72 0.35];   % muted amber
CMAP = [COL_ESCAPED; COL_DETECTED; COL_EQUIVALENT];

FONT = 'Times New Roman';

% =========================================================================
%  SECTION 1 — SoC INTERCONNECT MUTANTS  M01–M10
% =========================================================================

soc_ids = {'M01','M02','M03','M04','M05','M06','M07','M08','M09','M10'};

% M05: vdp_write ignored by slave  -> equivalent in ALL flows
% M09: RAM addr[1:0] always 00     -> equivalent in ALL flows
% FIX: both must be coded 2 across all three rows (not 0 in directed/passive)
soc_dir = [1 0 0 0  2  0 0 1  2  0];
soc_pas = [1 0 0 0  2  0 0 1  2  0];
soc_act = [1 1 1 1  2  1 1 1  2  1];

D_soc = [soc_dir; soc_pas; soc_act];

%% Figure 10(a): SoC mutation-detection matrix
figure('Units','inches','Position',[1 1 7.2 4.4],'Color','w');
imagesc(D_soc); axis tight;
colormap(CMAP); caxis([0 2]);

set(gca,'XTick',1:10,'XTickLabel',soc_ids, ...
        'YTick',1:3,'YTickLabel',{'Directed FW','Passive UVM','Active UVM'}, ...
        'FontName',FONT,'FontSize',10,'LineWidth',0.8,'TickDir','out');
xlabel('Mutation ID','FontName',FONT,'FontSize',11);
ylabel('Verification approach','FontName',FONT,'FontSize',11);
hold on;

for r = 0.5:1:3.5,  plot([0.5 10.5],[r r],'k-','LineWidth',0.45); end
for c = 0.5:1:10.5, plot([c c],[0.5 3.5],'k-','LineWidth',0.45); end

for r = 1:3
    for c = 1:10
        switch D_soc(r,c)
            case 1, lbl = 'D'; tc = [1 1 1];
            case 2, lbl = 'E'; tc = [1 1 1];
            otherwise, lbl = char(8212); tc = [0.15 0.15 0.15];  % em-dash
        end
        text(c,r,lbl,'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontName',FONT,'FontSize',10,'FontWeight','bold','Color',tc);
    end
end

text(0.5,-0.14,'D = detected    E = equivalent    — = escaped/unobservable', ...
    'Units','normalized','FontName',FONT,'FontSize',9);
set(gca,'YDir','reverse'); box on;

exportgraphics(gcf,'Fig10a_mutation_detection_matrix.pdf','ContentType','vector');
exportgraphics(gcf,'Fig10a_mutation_detection_matrix.png','Resolution',600);

%% Figure 10(b): SoC viable-mutation detection rate
soc_viable = [1 2 3 4 6 7 8 10];   % excludes M05(col5) and M09(col9)
V_soc  = D_soc(:, soc_viable);
det_soc = sum(V_soc == 1, 2);
N_soc   = size(V_soc, 2);
rate_soc = 100 * det_soc / N_soc;

figure('Units','inches','Position',[1 1 6.2 4.1],'Color','w');
b = bar(rate_soc, 0.55);
b.FaceColor = 'flat';
b.CData = [COL_ESCAPED; COL_DETECTED; COL_DETECTED];  % Active UVM teal

set(gca,'XTick',1:3,'XTickLabel',{'Directed FW','Passive UVM','Active UVM'}, ...
        'FontName',FONT,'FontSize',10,'LineWidth',0.8,'TickDir','out');
ylabel('Detection rate of viable mutations (%)','FontName',FONT,'FontSize',11);
ylim([0 115]); yticks(0:20:100); grid off; box on;

for k = 1:3
    text(k, rate_soc(k)+4, sprintf('%d/%d (%.0f%%)', det_soc(k), N_soc, rate_soc(k)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontName',FONT,'FontSize',10);
end

exportgraphics(gcf,'Fig10b_mutation_detection_summary.pdf','ContentType','vector');
exportgraphics(gcf,'Fig10b_mutation_detection_summary.png','Resolution',600);

% =========================================================================
%  SECTION 2 — TPU MUTANTS  M_TPU_01–05
% =========================================================================

tpu_ids = {'M\_TPU\_01','M\_TPU\_02','M\_TPU\_03','M\_TPU\_04','M\_TPU\_05'};

% M_TPU_03: read mux fault — firmware never reads input regs back -> escaped
% All others detected by all flows. No equivalent mutants in TPU set.
tpu_dir = [1 1 0 1 1];
tpu_pas = [1 1 0 1 1];
tpu_act = [1 1 1 1 1];

D_tpu = [tpu_dir; tpu_pas; tpu_act];

%% Figure 10(c): TPU mutation-detection matrix
figure('Units','inches','Position',[1 1 5.5 4.4],'Color','w');
imagesc(D_tpu); axis tight;
colormap(CMAP); caxis([0 2]);

set(gca,'XTick',1:5,'XTickLabel',tpu_ids, ...
        'YTick',1:3,'YTickLabel',{'Directed FW','Passive UVM','Active UVM'}, ...
        'FontName',FONT,'FontSize',10,'LineWidth',0.8,'TickDir','out');
xlabel('Mutation ID','FontName',FONT,'FontSize',11);
ylabel('Verification approach','FontName',FONT,'FontSize',11);
hold on;

for r = 0.5:1:3.5, plot([0.5 5.5],[r r],'k-','LineWidth',0.45); end
for c = 0.5:1:5.5, plot([c c],[0.5 3.5],'k-','LineWidth',0.45); end

for r = 1:3
    for c = 1:5
        switch D_tpu(r,c)
            case 1, lbl = 'D'; tc = [1 1 1];
            otherwise, lbl = char(8212); tc = [0.15 0.15 0.15];
        end
        text(c,r,lbl,'HorizontalAlignment','center','VerticalAlignment','middle', ...
            'FontName',FONT,'FontSize',10,'FontWeight','bold','Color',tc);
    end
end

text(0.5,-0.14,'D = detected    — = escaped/unobservable', ...
    'Units','normalized','FontName',FONT,'FontSize',9);
set(gca,'YDir','reverse'); box on;

exportgraphics(gcf,'Fig10c_tpu_mutation_matrix.pdf','ContentType','vector');
exportgraphics(gcf,'Fig10c_tpu_mutation_matrix.png','Resolution',600);

%% Figure 10(d): TPU viable-mutation detection rate (all 5 viable)
det_tpu  = sum(D_tpu == 1, 2);
N_tpu    = 5;
rate_tpu = 100 * det_tpu / N_tpu;

figure('Units','inches','Position',[1 1 6.2 4.1],'Color','w');
b2 = bar(rate_tpu, 0.55);
b2.FaceColor = 'flat';
b2.CData = [COL_ESCAPED; COL_DETECTED; COL_DETECTED];

set(gca,'XTick',1:3,'XTickLabel',{'Directed FW','Passive UVM','Active UVM'}, ...
        'FontName',FONT,'FontSize',10,'LineWidth',0.8,'TickDir','out');
ylabel('Detection rate of viable mutations (%)','FontName',FONT,'FontSize',11);
ylim([0 115]); yticks(0:20:100); grid off; box on;

for k = 1:3
    text(k, rate_tpu(k)+4, sprintf('%d/%d (%.0f%%)', det_tpu(k), N_tpu, rate_tpu(k)), ...
        'HorizontalAlignment','center','VerticalAlignment','bottom', ...
        'FontName',FONT,'FontSize',10);
end

exportgraphics(gcf,'Fig10d_tpu_mutation_summary.pdf','ContentType','vector');
exportgraphics(gcf,'Fig10d_tpu_mutation_summary.png','Resolution',600);

% =========================================================================
%  CONSOLE SUMMARY
% =========================================================================
fprintf('\n=== SoC Interconnect Mutants (M01-M10) ===\n');
fprintf('Viable mutations : %d  (M05, M09 excluded as equivalent)\n', N_soc);
fprintf('Directed FW      : %d/%d detected (%.1f%%)\n', det_soc(1), N_soc, rate_soc(1));
fprintf('Passive UVM      : %d/%d detected (%.1f%%)\n', det_soc(2), N_soc, rate_soc(2));
fprintf('Active UVM       : %d/%d detected (%.1f%%)\n', det_soc(3), N_soc, rate_soc(3));

fprintf('\n=== TPU Mutants (M_TPU_01-05) ===\n');
fprintf('Viable mutations : %d  (no equivalents)\n', N_tpu);
fprintf('Directed FW      : %d/%d detected (%.1f%%)\n', det_tpu(1), N_tpu, rate_tpu(1));
fprintf('Passive UVM      : %d/%d detected (%.1f%%)\n', det_tpu(2), N_tpu, rate_tpu(2));
fprintf('Active UVM       : %d/%d detected (%.1f%%)\n', det_tpu(3), N_tpu, rate_tpu(3));
fprintf('\nM_TPU_03 escape: firmware never reads input registers back after writing.\n');
fprintf('Active UVM catches it via explicit readback with distinct INPUT0 != INPUT1.\n');
