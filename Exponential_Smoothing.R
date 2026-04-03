# ╔═══════════════════════════════════════════════════════════════════════════════╗
# ║  ECON 3343/6635: Smoothing Methods                             ║
# ║  Dataset: Australian Wines (1980-1994, monthly)                             ║
# ║  R Ecosystem: fpp3 (tsibble, fable, feasts, ggplot2)                        ║
# ║                                                                             ║
# ║  SAME FRAMEWORK AS Baregg (Baregg Tunnel):                                     ║
# ║    read.csv → tsibble → partition → model → forecast → accuracy → diagnose  ║
# ╚═══════════════════════════════════════════════════════════════════════════════╝


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 1: LOAD PACKAGES & DATA
# Same packages as the Baregg Tunnel code
# ═══════════════════════════════════════════════════════════════════════════════

library(fpp3)      # loads tsibble, fable, feasts, ggplot2, dplyr, lubridate
# If you don't have fpp3 installed:
# install.packages("fpp3")

setwd("C:/Users/samri/OneDrive/Desktop/ECON 6635 Business Forecasting/Week 5")

# ── Read CSV & create a tsibble ──────────────────────────────────────────────
# In Baregg we used:  mutate(Day = ymd(Day))  → daily data
# Here we use:     mutate(Month = yearmonth(my(Month))) → monthly data
# my() from lubridate parses "Jan-80" into a Date, yearmonth() converts it

wines_raw <- read.csv("AustralianWines.csv") |>
  mutate(Month = yearmonth(my(Month))) |>      # my() parses "Jan-80" → Date, then yearmonth()
  as_tsibble(index = Month)                    # declare time index → R "knows" it's a time series

# Quick data checks
glimpse(wines_raw)
# Rows: 180  Columns: 7
# Month [1M], Fortified, Red, Rose, Sparkling, Sweet.white, Dry.white

summary(wines_raw)

# ── Focus on Fortified wine for the main example ─────────────────────────────
fortified <- wines_raw |>
  select(Month, Fortified)

# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 2: EXPLORATORY DATA ANALYSIS (EDA)
# ═══════════════════════════════════════════════════════════════════════════════

# ── Time series plot ─────────────────────────────────────────────────────────
autoplot(fortified, Fortified) +
  labs(title = "Australian Fortified Wine Sales (1980-1994)",
       y = "Sales (thousands of liters)",
       x = "Month") +
  theme_minimal()
# WHAT TO SEE:
#   - Clear downward trend (fortified wine declining in popularity)
#   - Strong 12-month seasonality (peaks around July-Aug = Australian winter)
#   - Seasonal amplitude shrinks as level drops → multiplicative seasonality?

# ── All six wine types at once ───────────────────────────────────────────────
wines_raw |>
  pivot_longer(-Month, names_to = "Wine_Type", values_to = "Sales") |>
  autoplot(Sales) +
  facet_wrap(~ Wine_Type, scales = "free_y", ncol = 2) +
  labs(title = "Australian Wine Sales by Type",
       y = "Sales (thousands of liters)") +
  theme_minimal() +
  theme(legend.position = "none")
# DISCUSSION:
#   - Fortified: downward trend + seasonality
#   - Red: upward trend + seasonality
#   - Sparkling: huge December spikes (Christmas!)
#   - Dry.white: mild upward trend


# ── Boxplots by wine type ────────────────────────────────────────────────────
wines_raw |>
  pivot_longer(-Month, names_to = "Wine_Type", values_to = "Sales") |>
  ggplot(aes(x = Wine_Type, y = Sales, fill = Wine_Type)) +
  geom_boxplot(show.legend = FALSE) +
  labs(title = "Distribution of Sales by Wine Type",
       y = "Sales (thousands of liters)") +
  theme_minimal()


# ── Seasonal subseries plot (feasts package) ─────────────────────────────────
fortified |>
  gg_subseries(Fortified) +
  labs(title = "Seasonal Subseries: Fortified Wine by Month",
       y = "Sales (thousands of liters)")
# Each mini-panel = one month across all years
# Blue horizontal line = month mean
# If monthly means differ greatly → strong seasonality


# ── ACF plot (same idea as Baregg, but now checking for lag-12) ─────────────────
fortified |>
  ACF(Fortified, lag_max = 36) |>
  autoplot() +
  labs(title = "ACF: Fortified Wine Sales (up to 36 months)")
# WHAT TO SEE:
#   - Slow decay → trend component
#   - Spikes at lag 12, 24, 36 → annual seasonality
# Compare to Baregg Tunnel: there we saw lag-7 spikes (weekly seasonality)


# ── STL decomposition ────────────────────────────────────────────────────────
# STL = Seasonal and Trend decomposition using Loess (pronounced LOW-ess)
# This replaces the old decompose() function

fortified |>
  model(STL(Fortified ~ trend(window = 21) +
              season(window = "periodic"))) |>
  components() |>
  autoplot() +
  labs(title = "STL Decomposition: Fortified Wine Sales")
# FOUR PANELS:
#   1. Original data
#   2. Trend component (long-term movement, clearly declining)
#   3. Seasonal component (repeating 12-month pattern)
#   4. Remainder (should look random — if not, model needs more)


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 3: PARTITION INTO TRAINING & VALIDATION
# Same logic as Baregg: hold out the final period for evaluation
# ═══════════════════════════════════════════════════════════════════════════════

# In  (Baregg Tunnel, daily):
#   train <- baregg |> filter(Day < ymd("2005-07-01"))
#   valid <- baregg |> filter(Day >= ymd("2005-07-01"))
#
# Here (Australian Wines, monthly): last 12 months = validation

train <- fortified |> filter(year(Month) < 1994)      # 1980-01 to 1993-12 (168 months)
valid <- fortified |> filter(year(Month) >= 1994)      # 1994-01 to 1994-12 (12 months)

cat("Training:", nrow(train), "months\n")
cat("Validation:", nrow(valid), "months\n")


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 4: FIT SMOOTHING MODELS WITH ETS
# This is where Ch5 goes BEYOND Baregg's NAIVE/TSLM
#
# PERFORMANCE NOTE: Each ETS() runs a numerical optimizer, so we fit
# all models ONCE here and reuse them in later sections via select().
# ═══════════════════════════════════════════════════════════════════════════════

fit <- train |>
  model(
    # ── Benchmark (from Baregg) ──
    snaive   = SNAIVE(Fortified),                                          # seasonal naive (MASE = 1.0 by definition)
    
    # ── Smoothing models (Ch5) ──
    ses      = ETS(Fortified ~ error("A") + trend("N") + season("N")),     # Simple Exponential Smoothing: level only
    holt     = ETS(Fortified ~ error("A") + trend("A") + season("N")),     # Holt's Linear: level + trend
    hw_add   = ETS(Fortified ~ error("A") + trend("A") + season("A")),     # Holt-Winters Additive
    hw_mult  = ETS(Fortified ~ error("A") + trend("A") + season("M")),     # Holt-Winters Multiplicative
    hw_damped= ETS(Fortified ~ error("A") + trend("Ad") + season("M"))     # HW Multiplicative + Damped trend
  )

# ── View all fitted parameters ───────────────────────────────────────────────
fit |>
  tidy() |>
  print(n = 50)
# Compare the optimized alpha, beta, gamma to textbook defaults (0.2, 0.15, 0.05)

# ── Information criteria (AIC/AICc/BIC) ──────────────────────────────────────
fit |>
  glance() |>
  select(.model, AIC, AICc, BIC) |>
  arrange(AICc)
# Lower AICc = better balance of fit vs complexity


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 5: FORECAST & EVALUATE
# Same accuracy() function from Baregg — same metrics, same interpretation
# ═══════════════════════════════════════════════════════════════════════════════

# ── Generate forecasts (reuses fit — no refitting!) ──────────────────────────
fc <- fit |> forecast(h = 12)
fc

# ── Plot forecasts vs actuals ────────────────────────────────────────────────
# We extract .mean and use ggplot directly (much faster than autoplot on fable)

fc_plot <- fc |>
  as_tibble() |>
  select(.model, Month, .mean)

ggplot() +
  autolayer(fortified, Fortified, color = "black") +
  geom_line(data = fc_plot, aes(x = Month, y = .mean, color = .model), linewidth = 0.8) +
  labs(title = "ETS Forecast Comparison: Fortified Wine (1994)",
       y = "Sales (thousands of liters)",
       x = "Month",
       color = "Model") +
  theme_minimal()
# WHAT TO SEE:
#   - SES: flat line (no trend, no season) — clearly inadequate
#   - Holt: downward trend but no seasonality
#   - HW_add: has seasonal shape but wrong amplitude
#   - HW_mult: captures the seasonal pattern that shrinks with level

# ── Accuracy table (THE PAYOFF FROM Baregg) ─────────────────────────────────────
acc <- accuracy(fc, fortified) |>
  select(.model, ME, RMSE, MAE, MAPE, MASE) |>
  arrange(MASE)

print(acc)
# MASE INTERPRETATION (same as Baregg):
#   MASE < 1  →  model beats seasonal naive (good!)
#   MASE = 1  →  ties with seasonal naive
#   MASE > 1  →  worse than seasonal naive (why bother?)

# ── Head-to-head: best ETS vs SNAIVE ────────────────────────────────────────
best_model_name <- acc$.model[1]
cat("\nBest model:", best_model_name, "\n")
cat("MASE:", acc$MASE[acc$.model == best_model_name], "\n")


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 6: RESIDUAL DIAGNOSTICS
# Same tools as Baregg: gg_tsresiduals(), ACF, Ljung-Box
#
# KEY: We use select() to extract models from the already-fitted `fit` object.
# This avoids refitting and is instant.
# ═══════════════════════════════════════════════════════════════════════════════

# ── Extract hw_mult from the ALREADY-FITTED models ───────────────────────────
best_fit <- fit |> select(hw_mult)

# ── 3-panel residual diagnostics ─────────────────────────────────────────────
best_fit |>
  gg_tsresiduals() +
  labs(title = "Residual Diagnostics: Holt-Winters Multiplicative (AAM)")
# PANEL 1 (Time plot): Should look random, no patterns
# PANEL 2 (ACF): All bars inside blue dashed lines
#   - lag-12 spike → missed annual seasonality
#   - lag-1 spike → missed short-term dynamics (ARIMA territory)
#   - COMPARE TO Baregg: Baregg Tunnel LinReg had lag-7 spike (weekly pattern)
# PANEL 3 (Histogram): Roughly bell-shaped and centered at zero

# ── Ljung-Box test (formal version of the ACF check) ────────────────────────
# In Baregg: lag = 14 (2 weeks x 7 days/week)
# Here:   lag = 24 (2 years x 12 months/year)
lb_result <- best_fit |>
  augment() |>
  features(.innov, ljung_box, lag = 24)

print(lb_result)
#   p > 0.05: "Residuals are consistent with white noise" (model adequate)
#   p < 0.05: "Significant leftover structure" (model incomplete)

# ── Compare Ljung-Box across models (reuses fit — no refitting!) ─────────────
fit |>
  select(snaive, hw_add, hw_mult, hw_damped) |>
  augment() |>
  features(.innov, ljung_box, lag = 24)

# ── Residual ACF by model (reuses fit) ───────────────────────────────────────
fit |>
  select(snaive, hw_add, hw_mult, hw_damped) |>
  augment() |>
  ACF(.innov, lag_max = 36) |>
  autoplot() +
  facet_wrap(~ .model) +
  labs(title = "Residual ACF by Model (should be within blue bands)")


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 7: PREDICTION INTERVALS
# Same two approaches from Baregg: theoretical (built-in) and empirical
# ═══════════════════════════════════════════════════════════════════════════════

# ── Theoretical prediction intervals (reuses best_fit — no refitting!) ───────
fc_best <- best_fit |> forecast(h = 12)

fc_best |>
  autoplot(fortified, level = c(80, 95)) +
  labs(title = "Holt-Winters Multiplicative: Forecast with Prediction Intervals",
       y = "Sales (thousands of liters)") +
  theme_minimal()
# The 80% and 95% bands show the range of plausible future values

# ── Empirical prediction intervals (from Baregg framework) ──────────────────────
validation_errors <- valid$Fortified - fc_best$.mean

cat("\nEmpirical Prediction Interval (from validation errors):\n")
cat("5th percentile:", quantile(validation_errors, 0.05), "\n")
cat("95th percentile:", quantile(validation_errors, 0.95), "\n")
cat("This means: the true value is typically between",
    round(quantile(validation_errors, 0.05)), "and",
    round(quantile(validation_errors, 0.95)),
    "units from the forecast.\n")


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 8: THE DEPLOYMENT DECISION
# Connecting back to our very first question in this class
# ═══════════════════════════════════════════════════════════════════════════════

cat("\n===================================================================\n")
cat("  DEPLOYMENT CHECKLIST (from Baregg, applied to Ch5)\n")
cat("===================================================================\n\n")

# Step 1: Does it beat the benchmark?
mase_val <- acc$MASE[acc$.model == "hw_mult"]
cat("1. MASE =", round(mase_val, 3), "->",
    ifelse(mase_val < 1, "BEATS seasonal naive", "LOSES to seasonal naive"), "\n")

# Step 2: Are residuals white noise? (reuses lb_result from Section 6)
cat("2. Ljung-Box p-value =", round(lb_result$lb_pvalue, 4), "->",
    ifelse(lb_result$lb_pvalue > 0.05,
           "Residuals are white noise",
           "Residuals have structure"), "\n")

# Step 3: Is bias acceptable?
me_val <- acc$ME[acc$.model == "hw_mult"]
cat("3. ME =", round(me_val, 1), "->",
    ifelse(abs(me_val) < 100,
           "Low bias",
           "Notable bias -- investigate direction"), "\n")

cat("\n")

# Step 4: Final recommendation
if (mase_val < 1 & lb_result$lb_pvalue > 0.05) {
  cat("RECOMMENDATION: Model is adequate for deployment.\n")
  cat("Monitor forecast errors monthly and refit quarterly.\n")
} else if (mase_val < 1 & lb_result$lb_pvalue <= 0.05) {
  cat("RECOMMENDATION: Model beats benchmark but residuals have structure.\n")
  cat("Consider: (a) try auto ETS, (b) add ARIMA (Ch7), (c) investigate outliers.\n")
} else {
  cat("RECOMMENDATION: Model does not beat seasonal naive. Do not deploy.\n")
}


# ═══════════════════════════════════════════════════════════════════════════════
# SECTION 10: EXERCISE — TRY A DIFFERENT WINE TYPE
# Apply the full Baregg-Ch5 workflow yourself!
# ═══════════════════════════════════════════════════════════════════════════════

# ── Choose your wine ─────────────────────────────────────────────────────────
# Uncomment ONE of the following:
# my_wine <- wines_raw |> select(Month, Sales = Red)
# my_wine <- wines_raw |> select(Month, Sales = Sparkling)
# my_wine <- wines_raw |> select(Month, Sales = Sweet.white)
# my_wine <- wines_raw |> select(Month, Sales = Dry.white)

# ── Then follow the same steps provided above ────────────────────────────────────
