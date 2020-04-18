%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% function [trial_data,bad_units] = removeBadNeurons(trial_data,params)
% 
%   Checks for shunts or duplicate neurons based on coincidence, and also
% removes low-firing cells.
%
% INPUTS:
%   trial_data : the struct
%   params     : parameter struct
%     .arrays         : list of arrays to work on
%     .do_shunt_check : flag to look for coincident spiking
%     .prctile_cutoff : value (0-100) for empirical test distribution
%     .do_fr_check    : flag to look for minimum firing rate
%     .min_fr         : minimum firing rate value to be a good cell
%             NOTE: assumes it's already a firing rate, i.e., it won't
%             divide by bin size
%     .fr_window      : when during trials to evaluate firing rate
%                           {'idx_BEGIN',BINS_AFTER;'idx_END',BINS_AFTER}
%     .use_trials     : can only use a subset of trials if desired
%     .calc_fr        : will divide by bin_size if true
%
% OUTPUTS:
%   trial_data : the struct with bad_units removed
%   bad_units  : list of indices in the original struct that are bad
%
% Written by Matt Perich. Updated Feb 2017.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [trial_data,bad_units] = removeBadNeurons(trial_data,params)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% DEFAULT PARAMETERS
arrays          =  [];
do_shunt_check  =  false;
prctile_cutoff  =  99.5;
do_fr_check     =  true;
min_fr          =  0;
fr_window       =  {};
calc_fr         =  false;
use_trials      =  1:length(trial_data);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Some undocumented extra parameters
verbose = false;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if nargin > 1, assignParams(who,params); end % overwrite defaults
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
trial_data = check_td_quality(trial_data);

bin_size        =  trial_data(1).bin_size;
if iscell(use_trials) % likely to be meta info
    use_trials = getTDidx(trial_data,use_trials{:});
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if isempty(arrays) % get all spiking arrays
    arrays = getTDfields(trial_data,'spikes');
    for a = 1:length(arrays)
        arrays{a} = strrep(arrays{a},'_spikes','');
    end
else
    if ~iscell(arrays), arrays = {arrays}; end
end

for a = 1:length(arrays)
    array = arrays{a};
    
    if isempty(fr_window)
        all_spikes = cat(1,trial_data(use_trials).([array '_spikes']));
    else
        td = trimTD(trial_data(use_trials),fr_window(1,:),fr_window(2,:));
        all_spikes = cat(1,td.([array '_spikes']));
    end
    
    bad_units = zeros(1,size(all_spikes,2));
    if do_shunt_check
        prctile_dist    =  get_master_dist();
        coinc = zeros(size(all_spikes,2));
        for unit1 = 1:size(all_spikes,2)
            for unit2 = 1:size(all_spikes,2)
                if unit1 ~= unit2
                    coinc(unit1,unit2) = 100*sum( (all_spikes(:,unit1) > 0) & ...
                        (all_spikes(:,unit2) > 0) & ...
                        (all_spikes(:,unit1) == all_spikes(:,unit2)))/ ...
                        size(all_spikes,1);
                end
            end
        end
        
        cutoff_val = prctile_dist(floor(10*prctile_cutoff));
        coinc = coinc > cutoff_val;
        
        for unit = 1:size(all_spikes,2)
            if any(coinc(unit,:) & coinc(:,unit)')
                bad_units(unit) = 1;
            end
        end
    end
    
    % Now check for low firing rate neurons
    if do_fr_check
        if calc_fr
            all_spikes  = all_spikes./trial_data(1).bin_size;
        end
        bad_units = bad_units | mean(all_spikes,1) < min_fr;
    end
    
    disp([arrays{a} ': found ' num2str(sum(bad_units)) ' bad units.']);
    
    % now remove the bad cells
    if sum(bad_units) > 0
        for trial = 1:length(trial_data)
            temp = trial_data(trial).([array '_spikes']);
            temp(:,bad_units) = [];
            trial_data(trial).([array '_spikes']) = temp;
            temp = trial_data(trial).([array '_unit_guide']);
            temp(bad_units,:) = [];
            trial_data(trial).([array '_unit_guide']) = temp;
        end
        bad_units = find(bad_units);
    else
        bad_units = [];
    end
end

end

function prctile_dist = get_master_dist()
% IDEAS FOR EXCLUSION CRITERIA
%   1) build "master" distribution using TONS of sessions and save it here
%   permanently (fit a distribution to it?)
%   2) use all pairs in a session to look for outlier pairs
%   3) give an arbitrary cutoff
% % % CODE TO CALCULATE MASTER DISTRIBUTION
% % root_dir = '/Users/mattperich/Data/TrialDataFiles/';
% % fn=dir([root_dir '*.mat']);
% % all_dist = [];
% % for i = 1:length(fn)
% %     load([root_dir fn(i).name]);
% %
% %     all_spikes = cat(1,trial_data.M1_spikes);
% %
% % perc_coinc = NaN(size(all_spikes,2));
% % for unit1 = 1:size(all_spikes,2)
% %     for unit2 = unit1:size(all_spikes,2)
% %         perc_coinc(unit1,unit2) = 100*sum( (all_spikes(:,unit1) > 0) & ...
% %                                             (all_spikes(:,unit2) > 0) & ...
% %                                             (all_spikes(:,unit1) == all_spikes(:,unit2))) ...
% %                                             /size(all_spikes,1);
% %     end
% % end
% % all_dist = [all_dist; reshape(perc_coinc,numel(perc_coinc),1)];
% % end
% % prctile_dist = prctile(all_dist,1:0.1:100);
prctile_dist = [ ...
    0
    0.0003
    0.0007
    0.0010
    0.0013
    0.0015
    0.0020
    0.0022
    0.0025
    0.0028
    0.0033
    0.0035
    0.0040
    0.0043
    0.0048
    0.0050
    0.0056
    0.0059
    0.0062
    0.0067
    0.0071
    0.0076
    0.0081
    0.0084
    0.0089
    0.0093
    0.0098
    0.0102
    0.0106
    0.0109
    0.0115
    0.0119
    0.0124
    0.0127
    0.0131
    0.0135
    0.0139
    0.0145
    0.0149
    0.0153
    0.0158
    0.0162
    0.0167
    0.0172
    0.0177
    0.0181
    0.0186
    0.0191
    0.0196
    0.0200
    0.0204
    0.0209
    0.0214
    0.0219
    0.0224
    0.0229
    0.0234
    0.0241
    0.0247
    0.0251
    0.0256
    0.0260
    0.0266
    0.0271
    0.0276
    0.0280
    0.0287
    0.0291
    0.0297
    0.0302
    0.0307
    0.0312
    0.0318
    0.0324
    0.0329
    0.0334
    0.0340
    0.0344
    0.0351
    0.0357
    0.0362
    0.0367
    0.0373
    0.0379
    0.0387
    0.0391
    0.0399
    0.0405
    0.0412
    0.0418
    0.0422
    0.0429
    0.0435
    0.0441
    0.0447
    0.0452
    0.0458
    0.0464
    0.0471
    0.0477
    0.0484
    0.0490
    0.0497
    0.0502
    0.0506
    0.0514
    0.0521
    0.0528
    0.0534
    0.0541
    0.0549
    0.0557
    0.0563
    0.0570
    0.0577
    0.0583
    0.0589
    0.0596
    0.0604
    0.0610
    0.0617
    0.0623
    0.0631
    0.0637
    0.0642
    0.0651
    0.0658
    0.0663
    0.0670
    0.0677
    0.0683
    0.0689
    0.0695
    0.0702
    0.0709
    0.0718
    0.0724
    0.0730
    0.0737
    0.0743
    0.0749
    0.0757
    0.0764
    0.0772
    0.0781
    0.0787
    0.0795
    0.0803
    0.0809
    0.0817
    0.0825
    0.0831
    0.0838
    0.0845
    0.0851
    0.0859
    0.0867
    0.0874
    0.0882
    0.0891
    0.0898
    0.0907
    0.0916
    0.0924
    0.0931
    0.0938
    0.0947
    0.0955
    0.0963
    0.0970
    0.0977
    0.0985
    0.0993
    0.1001
    0.1010
    0.1017
    0.1024
    0.1031
    0.1037
    0.1045
    0.1052
    0.1060
    0.1069
    0.1078
    0.1085
    0.1093
    0.1102
    0.1111
    0.1117
    0.1124
    0.1132
    0.1140
    0.1149
    0.1157
    0.1166
    0.1174
    0.1183
    0.1190
    0.1199
    0.1207
    0.1214
    0.1222
    0.1231
    0.1237
    0.1244
    0.1253
    0.1261
    0.1269
    0.1276
    0.1285
    0.1292
    0.1300
    0.1309
    0.1316
    0.1326
    0.1334
    0.1342
    0.1351
    0.1360
    0.1368
    0.1377
    0.1387
    0.1395
    0.1404
    0.1414
    0.1424
    0.1432
    0.1442
    0.1451
    0.1458
    0.1467
    0.1477
    0.1485
    0.1494
    0.1501
    0.1509
    0.1518
    0.1526
    0.1536
    0.1545
    0.1553
    0.1562
    0.1572
    0.1580
    0.1589
    0.1599
    0.1606
    0.1615
    0.1623
    0.1632
    0.1641
    0.1651
    0.1660
    0.1669
    0.1678
    0.1688
    0.1697
    0.1705
    0.1715
    0.1723
    0.1732
    0.1740
    0.1751
    0.1761
    0.1772
    0.1782
    0.1791
    0.1801
    0.1810
    0.1819
    0.1830
    0.1839
    0.1850
    0.1860
    0.1867
    0.1878
    0.1886
    0.1897
    0.1908
    0.1919
    0.1928
    0.1939
    0.1950
    0.1960
    0.1969
    0.1978
    0.1988
    0.1998
    0.2009
    0.2019
    0.2028
    0.2039
    0.2050
    0.2059
    0.2071
    0.2081
    0.2093
    0.2105
    0.2116
    0.2127
    0.2136
    0.2145
    0.2157
    0.2166
    0.2176
    0.2186
    0.2196
    0.2209
    0.2221
    0.2232
    0.2243
    0.2252
    0.2266
    0.2277
    0.2287
    0.2298
    0.2309
    0.2320
    0.2333
    0.2345
    0.2357
    0.2366
    0.2374
    0.2383
    0.2394
    0.2405
    0.2419
    0.2428
    0.2440
    0.2451
    0.2464
    0.2477
    0.2488
    0.2501
    0.2511
    0.2525
    0.2538
    0.2550
    0.2562
    0.2571
    0.2581
    0.2592
    0.2603
    0.2614
    0.2625
    0.2636
    0.2649
    0.2661
    0.2672
    0.2682
    0.2693
    0.2706
    0.2717
    0.2726
    0.2739
    0.2750
    0.2762
    0.2774
    0.2788
    0.2798
    0.2812
    0.2824
    0.2836
    0.2850
    0.2862
    0.2873
    0.2885
    0.2898
    0.2912
    0.2924
    0.2934
    0.2946
    0.2960
    0.2972
    0.2981
    0.2995
    0.3006
    0.3020
    0.3032
    0.3042
    0.3055
    0.3067
    0.3080
    0.3096
    0.3107
    0.3124
    0.3136
    0.3148
    0.3162
    0.3173
    0.3185
    0.3197
    0.3211
    0.3225
    0.3238
    0.3254
    0.3268
    0.3283
    0.3294
    0.3306
    0.3320
    0.3333
    0.3345
    0.3360
    0.3374
    0.3387
    0.3399
    0.3412
    0.3428
    0.3441
    0.3454
    0.3468
    0.3482
    0.3497
    0.3510
    0.3526
    0.3540
    0.3553
    0.3568
    0.3583
    0.3597
    0.3612
    0.3629
    0.3642
    0.3655
    0.3668
    0.3683
    0.3697
    0.3712
    0.3728
    0.3742
    0.3758
    0.3771
    0.3786
    0.3802
    0.3817
    0.3831
    0.3843
    0.3857
    0.3872
    0.3889
    0.3906
    0.3923
    0.3939
    0.3951
    0.3963
    0.3979
    0.3993
    0.4010
    0.4029
    0.4045
    0.4062
    0.4075
    0.4090
    0.4108
    0.4127
    0.4145
    0.4165
    0.4182
    0.4200
    0.4216
    0.4233
    0.4248
    0.4263
    0.4282
    0.4297
    0.4312
    0.4327
    0.4347
    0.4363
    0.4381
    0.4398
    0.4414
    0.4430
    0.4443
    0.4460
    0.4476
    0.4492
    0.4512
    0.4528
    0.4544
    0.4560
    0.4578
    0.4594
    0.4615
    0.4634
    0.4650
    0.4670
    0.4689
    0.4705
    0.4721
    0.4736
    0.4755
    0.4776
    0.4792
    0.4811
    0.4829
    0.4846
    0.4866
    0.4888
    0.4907
    0.4927
    0.4946
    0.4963
    0.4982
    0.4997
    0.5013
    0.5029
    0.5047
    0.5063
    0.5085
    0.5107
    0.5130
    0.5152
    0.5173
    0.5194
    0.5210
    0.5232
    0.5253
    0.5276
    0.5292
    0.5314
    0.5333
    0.5352
    0.5377
    0.5394
    0.5415
    0.5436
    0.5457
    0.5480
    0.5502
    0.5525
    0.5544
    0.5567
    0.5586
    0.5610
    0.5634
    0.5654
    0.5676
    0.5700
    0.5721
    0.5739
    0.5763
    0.5777
    0.5800
    0.5821
    0.5841
    0.5868
    0.5889
    0.5916
    0.5938
    0.5967
    0.5993
    0.6017
    0.6044
    0.6072
    0.6092
    0.6118
    0.6143
    0.6166
    0.6191
    0.6212
    0.6238
    0.6264
    0.6283
    0.6305
    0.6332
    0.6357
    0.6380
    0.6406
    0.6434
    0.6460
    0.6479
    0.6509
    0.6529
    0.6557
    0.6581
    0.6610
    0.6634
    0.6653
    0.6676
    0.6699
    0.6728
    0.6755
    0.6782
    0.6808
    0.6838
    0.6866
    0.6889
    0.6922
    0.6946
    0.6977
    0.7005
    0.7034
    0.7059
    0.7088
    0.7113
    0.7141
    0.7172
    0.7200
    0.7230
    0.7261
    0.7289
    0.7315
    0.7345
    0.7374
    0.7409
    0.7433
    0.7462
    0.7491
    0.7521
    0.7547
    0.7575
    0.7605
    0.7637
    0.7663
    0.7692
    0.7724
    0.7752
    0.7775
    0.7808
    0.7839
    0.7865
    0.7896
    0.7927
    0.7962
    0.7990
    0.8015
    0.8043
    0.8073
    0.8104
    0.8140
    0.8168
    0.8197
    0.8231
    0.8270
    0.8304
    0.8335
    0.8367
    0.8402
    0.8437
    0.8469
    0.8502
    0.8532
    0.8569
    0.8606
    0.8641
    0.8681
    0.8708
    0.8742
    0.8779
    0.8815
    0.8841
    0.8877
    0.8913
    0.8947
    0.8983
    0.9023
    0.9056
    0.9092
    0.9129
    0.9162
    0.9204
    0.9242
    0.9279
    0.9322
    0.9358
    0.9392
    0.9425
    0.9460
    0.9499
    0.9541
    0.9578
    0.9616
    0.9658
    0.9693
    0.9724
    0.9770
    0.9817
    0.9853
    0.9891
    0.9933
    0.9972
    1.0015
    1.0058
    1.0111
    1.0146
    1.0186
    1.0234
    1.0265
    1.0303
    1.0345
    1.0385
    1.0435
    1.0481
    1.0522
    1.0572
    1.0617
    1.0666
    1.0717
    1.0759
    1.0808
    1.0852
    1.0892
    1.0941
    1.0990
    1.1034
    1.1077
    1.1129
    1.1174
    1.1224
    1.1267
    1.1316
    1.1361
    1.1420
    1.1471
    1.1518
    1.1565
    1.1614
    1.1665
    1.1714
    1.1771
    1.1829
    1.1884
    1.1933
    1.1984
    1.2039
    1.2090
    1.2135
    1.2185
    1.2238
    1.2284
    1.2335
    1.2383
    1.2448
    1.2504
    1.2567
    1.2619
    1.2679
    1.2742
    1.2799
    1.2856
    1.2918
    1.2970
    1.3015
    1.3069
    1.3127
    1.3196
    1.3258
    1.3312
    1.3361
    1.3416
    1.3474
    1.3524
    1.3582
    1.3642
    1.3711
    1.3771
    1.3834
    1.3899
    1.3968
    1.4032
    1.4104
    1.4175
    1.4229
    1.4297
    1.4349
    1.4404
    1.4479
    1.4536
    1.4607
    1.4680
    1.4747
    1.4811
    1.4867
    1.4931
    1.5010
    1.5070
    1.5138
    1.5208
    1.5273
    1.5351
    1.5426
    1.5493
    1.5571
    1.5640
    1.5727
    1.5797
    1.5872
    1.5942
    1.6021
    1.6091
    1.6165
    1.6226
    1.6307
    1.6388
    1.6460
    1.6537
    1.6614
    1.6688
    1.6765
    1.6843
    1.6923
    1.6997
    1.7085
    1.7170
    1.7250
    1.7342
    1.7414
    1.7490
    1.7564
    1.7658
    1.7728
    1.7816
    1.7919
    1.8006
    1.8095
    1.8210
    1.8308
    1.8405
    1.8500
    1.8595
    1.8707
    1.8810
    1.8904
    1.8993
    1.9072
    1.9187
    1.9299
    1.9399
    1.9522
    1.9614
    1.9725
    1.9802
    1.9893
    2.0012
    2.0123
    2.0214
    2.0308
    2.0403
    2.0497
    2.0628
    2.0753
    2.0878
    2.0980
    2.1075
    2.1193
    2.1284
    2.1409
    2.1505
    2.1620
    2.1742
    2.1859
    2.1975
    2.2112
    2.2237
    2.2337
    2.2449
    2.2593
    2.2747
    2.2871
    2.3014
    2.3153
    2.3281
    2.3428
    2.3584
    2.3730
    2.3870
    2.4014
    2.4171
    2.4307
    2.4465
    2.4603
    2.4758
    2.4893
    2.5067
    2.5205
    2.5352
    2.5506
    2.5667
    2.5798
    2.5943
    2.6095
    2.6272
    2.6435
    2.6607
    2.6756
    2.6926
    2.7111
    2.7283
    2.7450
    2.7647
    2.7871
    2.8092
    2.8306
    2.8511
    2.8672
    2.8921
    2.9132
    2.9336
    2.9598
    2.9794
    3.0026
    3.0220
    3.0430
    3.0611
    3.0799
    3.0985
    3.1195
    3.1403
    3.1596
    3.1837
    3.2110
    3.2324
    3.2585
    3.2834
    3.3113
    3.3395
    3.3665
    3.3952
    3.4201
    3.4485
    3.4773
    3.5114
    3.5387
    3.5714
    3.5979
    3.6291
    3.6637
    3.6991
    3.7324
    3.7636
    3.7989
    3.8310
    3.8683
    3.9113
    3.9505
    3.9866
    4.0248
    4.0695
    4.1070
    4.1459
    4.1943
    4.2295
    4.2611
    4.3108
    4.3604
    4.4012
    4.4501
    4.5046
    4.5501
    4.6168
    4.6657
    4.7439
    4.7950
    4.8473
    4.8997
    4.9729
    5.0518
    5.1131
    5.1831
    5.2665
    5.3501
    5.4266
    5.5349
    5.6291
    5.7558
    5.8586
    5.9644
    6.0762
    6.2058
    6.3218
    6.4768
    6.6058
    6.7765
    6.9815
    7.1735
    7.4215
    7.6960
    7.9694
    8.2510
    8.5959
    9.0056
    9.5841
    10.1622
    10.8333
    11.3758
    12.0414
    12.6512
    13.5133
    14.3664
    15.5218
    16.5090
    17.9311
    19.2620
    21.0162
    22.9970
    25.2400
    29.8258
    54.9793];
end