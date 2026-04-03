# Exponential Smoothing on Australian Wine Dataset
### Link: https://sambridee-mahat.github.io/projects/wine-forecasting/ForecastingAnalysis.html 

Author: Sambridee Mahat\
Date: March 2, 2026
######
### Overview:
This project applies exponential smoothing methods to forecast monthly red wine sales in Australia using the Australian Wines dataset. The dataset contains monthly sales volumes (in thousands of litres) for six wine types — Fortified, Red, Rose, Sparkling, Sweet White, and Dry White — spanning January 1980 to December 1994 (180 observations).
Red wine was selected for this analysis due to its clearly identifiable upward trend, strong 12-month seasonality, and multiplicative seasonal structure — making it an ideal candidate to benchmark a range of ETS (Error-Trend-Seasonality) smoothing models.

### Objectives 
- Explore and decompose the red wine time series to identify key structural patterns.
- Fit and compare multiple exponential smoothing models (SES, Holt, Holt-Winters Additive/Multiplicative, Damped).
- Evaluate forecast accuracy against a seasonal naïve benchmark using MASE, RMSE, MAE, MAPE, and ME.
- Diagnose model residuals via the Ljung-Box test and ACF plots.
- Construct empirical and theoretical prediction intervals for the best-performing model.
  
#### Repository Structure
australian-wine-forecasting/\
  ├── AustralianWines.csv\
  ├── ForecastingAnalysis.html\
  └── README.md

### Methodology

### 1. Data Exploration
The time series was visualized and decomposed to understand its structure across four complementary diagnostics.
- **Time series plot:**          confirms a clear upward trend from ~500 to ~3,500 thousand litres over 15 years.
- **Seasonal subseries plot:**   reveals that July and August consistently peak each year, while January shows the lowest monthly average.
- **ACF plot:**                  hows significant autocorrelation at lags 12, 24, and 36, confirming strong annual seasonality.
- **STL decomposition:**         separates trend, seasonal, and remainder; the growing seasonal amplitude in the raw series points toward multiplicative seasonality.

### 2. Train / Validation Split

  | Split | Period | Observations |
  |:------|:-------|:-------------|
  | Training | Jan 1980 – Dec 1993 | 168 months |
  | Validation | Jan 1994 – Dec 1994 | 12 months |

### 3. Models Fitted
All models were estimated via maximum likelihood using the fable package in R.

  | Model | ETS Notation | Description |
  |:------|:-------------|:------------|
  | `snaive` | — | Seasonal Naïve (benchmark) |
  | `ses` | ETS(A,N,N) | Simple Exponential Smoothing — level only |
  | `holt` | ETS(A,A,N) | Holt's Linear — level + trend |
  | `hw_add` | ETS(A,A,A) | Holt-Winters Additive seasonality |
  | `hw_mult` | ETS(A,A,M) | Holt-Winters Multiplicative seasonality |
  | `hw_damped` | ETS(A,Ad,M) | Holt-Winters Multiplicative + damped trend |


### 4. Model Parameters
Key optimized smoothing parameters from the training fit:

  | Model | α (level) | β (trend) | γ (season) | φ (damp) |
  |:------|----------:|----------:|-----------:|---------:|
  | SES | 0.588 | — | — | — |
  | Holt | 0.581 | 0.0001 | — | — |
  | HW Additive | 0.115 | 0.0001 | 0.0001 | — |
  | HW Multiplicative | 0.174 | 0.0001 | 0.0001 | — |
  | HW Damped | 0.177 | 0.0038 | 0.0001 | 0.975 |

The very small β and γ values across seasonal models indicate that the trend and seasonal components are extremely stable over time — the model relies heavily on historical patterns rather than recent updates.

### Results: 
Information Criteria (Training Fit)
Lower AICc indicates a better balance of fit versus model complexity:

  | Model | AIC | AICc | BIC |
  |:------|----:|-----:|----:|
  | `hw_mult` | 2634 | 2638 | 2687 |
  | `hw_damped` | 2635 | 2640 | 2692 |
  | `hw_add` | 2667 | 2671 | 2720 |
  | `ses` | 2882 | 2882 | 2892 |
  | `holt` | 2886 | 2886 | 2902 |

The Holt-Winters Multiplicative model achieves the lowest AICc on the training set, followed closely by the damped variant.

#### Validation Accuracy
Accuracy evaluated on the held-out 1994 data:

  | Model | ME | RMSE | MAE | MAPE | MASE |
  |:------|---:|-----:|----:|-----:|-----:|
  | `hw_mult` | 124.0 | 293 | 238 | 9.49% | **1.21** |
  | `hw_add` | 88.2 | 323 | 246 | 11.5% | 1.25 |
  | `hw_damped` | 175.0 | 302 | 258 | 10.3% | 1.32 |
  | `snaive` | 212.0 | 403 | 332 | 13.8% | 1.69 |
  | `holt` | -123.0 | 592 | 395 | 22.6% | 2.01 |
  | `ses` | -45.0 | 603 | 423 | 23.3% | 2.15 |

**Best model:** hw_mult with MASE = 1.21 and MAPE ≈ 9.5%. While hw_mult is the best performer, its MASE > 1 means it does not outperform the seasonal naïve benchmark on the validation set. The model’s residuals pass white noise tests, suggesting remaining error is largely unpredictable noise.

#### Residual Diagnostics
Diagnostics were run on the best model (hw_mult):
- **Residual time plot** — residuals appear randomly scattered around zero with no obvious trends or persistent runs.
- **Residual ACF** — all lags fall within 95% confidence bands; no remaining autocorrelation structure detected.
- **Residual histogram** — approximately symmetric and bell-shaped, centred near zero, consistent with white noise.
- **Ljung-Box test** - (lag = 24): statistic = 21.6, p-value = 0.600 → residuals are white noise.

For comparison, the snaive model fails the Ljung-Box test (p = 0.000234), confirming it leaves exploitable structure in its residuals.

#### Prediction Intervals
Forecast for Jan–Dec 1994 with 80% and 95% theoretical prediction intervals was generated from hw_mult. Empirical prediction interval derived from validation errors:

| Percentile | Error from Forecast |
|:-----------|:--------------------|
| 5th | −272 thousand litres |
| 95th | +511 thousand litres |

This means the model’s point forecasts are typically within roughly −272 to +511 thousand litres of the true value, providing a practical sense of forecast uncertainty for inventory or logistics planning.
Deployment Recommendation
Based on the three key deployment criteria:

| Criterion | Result | Threshold | Status |
|:----------|:-------|:----------|:------:|
| MASE < 1 (beats benchmark) | 1.213 | < 1.0 | ❌ |
| Ljung-Box p > 0.05 (white noise residuals) | 0.600 | > 0.05 | ✅ |
| Low mean error (bias) | ME = 124 | < 100 | ⚠️ |

Current recommendation: Do not deploy in production. The model does not beat the seasonal naïve on the 12-month validation window, and carries a consistent positive bias (~124 thousand litres over-forecast on average).

### Potential Improvements
- **ARIMA or SARIMA** — the ARIMA() function in fable can capture autocorrelation patterns that ETS models are not designed for.
- **Outlier handling** — extreme spikes may be distorting smoothing parameters; adjusting for outliers before fitting could improve stability.
- **External regressors** — incorporating GDP, population, or wine export volumes via dynamic regression may improve accuracy during structural shifts.
