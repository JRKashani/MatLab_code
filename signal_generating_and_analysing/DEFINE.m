%%% DEFINE %%%


%sine wave parameters
AMP   = 1;
FREQ  = 2;
PHASE = 3;

NUM_OF_SIGN  = 3;

SIGN = 1;
SINE = 2;
NOIS = 3;

NUM_OF_MOMNT = 4;

MEAN = 1;
RMS  = 2;
SKEW = 3;
KURT = 4;

MIN_CYCLES = 10;

NUM_OF_FIGS = 5;


% Histogram configuration
HIST_BINS     = 100;          % number of histogram bins, each bin is a precentile
 
% Welch 
WELCH_OVERLAP    = 0.5;       % fractional overlap [0, 1)
 
% Dominant frequency extraction
N_DOMINANT = 10;              % number of top dominant frequencies to report

WIN_SIZE = [512, 2048, 8192, 32768, 131072];  % window size