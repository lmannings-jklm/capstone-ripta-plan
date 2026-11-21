##########################################################
# Project: Harvard Data Science Capstone: Providence Transit Center
# Filename: test_04_fit_caret_operational_delay.R
# Purpose: Apply Machine Learning tools (R caret package) to evaluate
#          and benchmark Operational Delay Model A (Section 5.1).
#          Compares OLS, Ridge/Lasso Elastic Net, and Random Forest
#          using Cross-Validation (LOOCV / K-Fold CV).
# Author: Larry Mannings
# Date: 2026-10-07
#
# Inputs:
#   - data/ripta_kp_final_dataset.csv (N=335,933 trip observations)
#
# Outputs:
#   - data/caret_train_cv_metrics.csv
#   - data/caret_holdout_test_metrics.csv
#   - data/caret_feature_importance.csv
##########################################################

suppressPackageStartupMessages({
  library(tidyverse)
  library(caret)
  library(glmnet)
  library(randomForest)
  library(broom)
  library(doParallel)
  library(ranger)
})

options(scipen = 999)

# Automatic Working Directory Calibration
if (basename(getwd()) == "scripts") {
  setwd("..")
}

cat("==========================================================\n")
cat("  ML EVALUATION OF OPERATIONAL DELAY MODEL (CARET PIPELINE)\n")
cat("==========================================================\n\n")

data_file <- "data/ripta_kp_final_dataset.csv"
if (is.null(data_file)) {
  stop("Error: Clean trip dataset not found.")
}

cat(sprintf("Ingesting dataset from: %s\n", data_file))
df_raw <- read_csv(data_file, show_col_types = FALSE)

# Register multiple cores (leaves 1 core free for your OS)
cl <- makePSOCKcluster(detectCores() - 1)
registerDoParallel(cl)

# 2. Select 3 Core Predictors + Target
ml_df <- df_raw |> 
  select(
    delay_Pi_to_KP,         # Target (Y)
    time_of_day_factor,     # Predictor (X2)
    trip_freq_buses_hr,     # Predictor (X3)
    approach_direction,     # Predictor (X4)
  ) |> 
  mutate(
    approach_direction = relevel(factor(approach_direction), ref = "North")
  )  |> 
  na.omit()

cat(sprintf("Prepared modeling dataset with %d trip observations and 3 predictors.\n\n", nrow(ml_df)))

# 3. Independent Data Partitioning (80% Train, 20% Unseen Test Holdout)
set.seed(42)
train_idx <- createDataPartition(ml_df$delay_Pi_to_KP, p = 0.80, list = FALSE)
train_set <- ml_df[train_idx, ]
test_set  <- ml_df[-train_idx, ]

cat(sprintf("Training Partition (80%%) : %d trip observations\n", nrow(train_set)))
cat(sprintf("Holdout Test Set (20%%)   : %d trip observations\n\n", nrow(test_set)))

# 4. Define Resampling Control (5-Fold CV)
train_ctrl <- trainControl(
  method = "cv",
  number = 5,
  savePredictions = "final",
  allowParallel = TRUE
)

# 5. Train Benchmark Machine Learning Models
cat("Training Model 1: Ordinary Least Squares (OLS Regression)...\n")
fit_lm <- train(
  delay_Pi_to_KP ~ .,
  data = train_set,
  method = "lm",
  trControl = train_ctrl,
  preProcess = c("center", "scale")
)

cat("Training Model 2: Elastic Net Regularized Regression (glmnet)...\n")
fit_enet <- train(
  delay_Pi_to_KP ~ .,
  data = train_set,
  method = "glmnet",
  trControl = train_ctrl,
  preProcess = c("center", "scale"),
  tuneLength = 5
)

cat("Training Model 3: Random Forest Regression (randomForest)...\n")
fit_rf <- train(
  delay_Pi_to_KP ~ .,
  data = train_set,
  method = "ranger",
  trControl = train_ctrl,
  preProcess = c("center", "scale"),
  importance = "impurity",
  tuneLength = 3
)

# Stop the parallel cluster when finished
stopCluster(cl)
registerDoSEQ()

# 6. Cross-Validated Performance
models_list <- list(
  "Random Forest" = fit_rf,
  "OLS Linear Regression" = fit_lm,
  "Elastic Net (glmnet)" = fit_enet
)

cv_res <- resamples(models_list)
cat("\n==========================================================\n")
cat("  10-FOLD CROSS-VALIDATED TRAINING PERFORMANCE (80% TRAIN)\n")
cat("==========================================================\n")
print(summary(cv_res))

# 7. Unseen Holdout Test Performance
eval_holdout <- function(model_obj, model_name) {
  preds <- predict(model_obj, newdata = test_set)
  rmse_val <- sqrt(mean((test_set$delay_Pi_to_KP - preds)^2))
  r2_val   <- cor(test_set$delay_Pi_to_KP, preds)^2
  mae_val  <- mean(abs(test_set$delay_Pi_to_KP - preds))
  
  tibble(
    Model = model_name,
    Test_RMSE = round(rmse_val, 4),
    Test_Rsquared = round(r2_val, 4),
    Test_MAE = round(mae_val, 4)
  )
}

holdout_results <- bind_rows(
  eval_holdout(fit_rf, "Random Forest"),
  eval_holdout(fit_lm, "OLS Linear Regression"),
  eval_holdout(fit_enet, "Elastic Net (glmnet)")
)

cat("\n==========================================================\n")
cat("  INDEPENDENT HOLDOUT TEST PERFORMANCE (20% UNSEEN TEST)\n")
cat("==========================================================\n")
print(holdout_results)

# 8. Feature Importance Rankings
imp_rf <- varImp(fit_rf)$importance |> 
  as.data.frame() |> 
  rownames_to_column(var = "Predictor") |> 
  rename(Importance = Overall)  |> 
  mutate(Importance = round(Importance / max(Importance) * 100, 2))  |> 
  arrange(desc(Importance))

cat("\n==========================================================\n")
cat("  RANDOM FOREST RELATIVE FEATURE IMPORTANCE\n")
cat("==========================================================\n")
print(imp_rf)

# Export Outputs
output_dir <- "data"
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

write_csv(holdout_results, file.path(output_dir, "caret_holdout_test_metrics.csv"))
write_csv(imp_rf, file.path(output_dir, "caret_feature_importance.csv"))

train_metrics_df <- tibble(
  Model = rownames(summary(cv_res)$statistics$RMSE),
  Train_RMSE = summary(cv_res)$statistics$RMSE[, "Mean"],
  Train_Rsquared = summary(cv_res)$statistics$Rsquared[, "Mean"],
  Train_MAE = summary(cv_res)$statistics$MAE[, "Mean"]
)

write_csv(train_metrics_df, file.path(output_dir, "caret_train_cv_metrics.csv"))

cat("\n==========================================================\n")
cat("  CARET ML EVALUATION COMPLETE!\n")
cat("==========================================================\n")
