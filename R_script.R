:::{.callout-note}
---
  title: "Supervised learning competition"
author: 
  - Diamantidis Adam
- Diamantidis Dimitrios

date: 21-10-2023
format:
  html:
  toc: true
self-contained: true
code-fold: true
df-print: kable
---
  
  :::
  
  ```{r}
#| label: R packages
#| echo: false
#| warning: false
#| message: false

library(tidyverse)   # data manipulation
library(ggplot2)     # plots
library(patchwork)   # arranging plots
library(fastDummies) # dummy coding
library(caret)       # finding correlated features
library(glmnet)      # shrinkage methods
library(ranger)      # random forest
library(h2o)         # parameter tuning
library(gbm)         # gradient boosting trees
library(xgboost)     # xgboost
library(rpart)       # performing regression trees
library(rpart.plot)  # plotting regression trees
library(ipred)       # bagging
library(vcd)         # visualisation
library(lattice)     # visualisation
library(hrbrthemes)  # visualisation
library(viridis)     # visualisation
```

```{r}
#| label: Data loading
#| echo: false
test <- readRDS("data/test.rds")
train <- readRDS("data/train.rds")
```



# Data description

The data set contains several variables that capture essential information about the scores of students. The dataset consists of 316 observations and 31 variables of which "school", "sex", "address", "famsize", "Pstatus", "Mjob", "Fjob", "reason", "guardian", "schoolsup" , "famsup", "paid", "activities", "nursery", "higher", "internet", "romantic" are categorical variables and the rest are numeric.

The average age of students in the dataset is 17 years, with a standard deviation of 13.
Study hours vary from 1 to 4 hours per week, with a median of 2.03 hours.

In the following, we do some graphical analystics on specific variables.

```{r}
#| label: eda visualization 1
dotplot(train$absences ~ train$sex)
```

Absences clustering for low values are so similar for both gender, however, as for higher values female is ahead by a significant margin.

```{r}
#| label: eda visualization 2

par(mfrow = c(1, 2))

mosaicplot(table(train$famsize, train$Mjob),
           color = TRUE,
           xlab = "famsize", # label for x-axis
           ylab = "Mjob" # label for y-axis
)

mosaicplot(table(train$famsize, train$Fjob),
           color = TRUE,
           xlab = "famsize", # label for x-axis
           ylab = "Fjob" # label for y-axis
)
```

The relationship between family size and job are similar for both gender. other and service selection stand out.

```{r}
#| label: eda visualization 3
ggplot(train) +
  aes(x = absences, y = studytime) +
  geom_point()
```

The group spending most time on study doesn't have too much absences.

```{r}
#| label: eda visualization 4
score_density<- ggplot(data=train, aes(x=score, group=sex, fill=sex)) +
  geom_density(adjust = 1.5, alpha = 0.4) +
  theme_ipsum()
score_density
```

Score density is clustered around narrower gap with higher mean with female variable.

```{r}
#| label: eda visualization 6
ggplot(train, aes(x=reason, y=score, fill=reason)) + 
  geom_violin()
```

For the relationship between reason and score, "other" variable differs from the other with higher lowest rate.



# Data transformation and pre-processing

Since there are many categorical variables in the data set, we dummy coded those categorical variables.

We excluded the dummy coded variables Fedu_1, failures_3 and famrel_2 from the training data set, since the test data set did not have any matching records.

```{r}
#| label: Dummy coding

# exclude the continuous variables from dummy coding
ind <- c(
  which(colnames(train) == "age"), 
  which(colnames(train) == "absences"),
  which(colnames(train) == "score")
) 

# dummy coding the training data
train_dummy <- dummy_cols(
  train, 
  select_columns = colnames(train)[-ind], 
  # remove the variables used to generate dummy variables
  remove_selected_columns = TRUE,
  # drop the first dummy of every variable to avoid multicollinearity
  remove_first = TRUE
)

# exclude Fedu_1,failures_3 and famrel_2 since they are not in the test data
train_dummy <- train_dummy |> select(-c("Fedu_1", "failures_3", "famrel_2"))

# exclude the continuous variables from dummy coding
ind <- c(
  which(colnames(train) == "age"), 
  which(colnames(train) == "absences")
) 

# dummy coding the test data
test_dummy <- dummy_cols(
  test, 
  select_columns = colnames(test)[-ind], 
  # remove the variables used to generate dummy variables
  remove_selected_columns = TRUE,
  # drop the first dummy of every variable to avoid multicollinearity
  remove_first = TRUE
)
```



# Models Description

## Shrinkage 

After finding, that a plain linear model did not perform very well on the data, we decided to try three different Shrinkage methods, i.e., Lasso, Ridge and Elastic Net regression. Lasso regression is a linear model with a penalty term \lambda. This penalty term sets some coefficients to zero and therefore automatically performs feature selection. Ridge regression is similiar to Lasso regression. However, the penalty term sets the coefficients very close to zero. Lastly, an Elastic Net is a combination of Lasso and Ridge regression.\
\lambda defines the amount of the penalty and we fine-tuned it and refit the models using the best performing \lambda.

Doing 10-folds Cross-Validation, comparing Lasso, Ridge and Elastic Nets, Ridge regression performed the best having an MSE of 0.73.

```{r}
#| label: Shrinkage methods

set.seed(42)

# row sampling for 10-fold CV
folds <- sample(1:10, size = nrow(train), replace = TRUE)

# prepare the matrix to store the results
mse_matrix <- matrix(data = rep(0, 3 * 10), nrow = 10, ncol = 3)
colnames(mse_matrix) <- c("Lasso", "Ridge", "Elastic Net")

# 10 CV
for (i in 1:10) {
  
  test <- folds == i
  
  # fit Lasso Regression for different lambdas
  cv_lasso <- cv.glmnet(
    as.matrix(train_dummy[, colnames(train_dummy) != "score"]),
    train_dummy$score,
    alpha = 1,
    standardize = TRUE,
    nfolds = 10,
    subset = !test
  )
  
  # fit Ridge Regression for different lambdas
  cv_ridge <- cv.glmnet(
    as.matrix(train_dummy[, colnames(train_dummy) != "score"]),
    train_dummy$score,
    alpha = 0,
    standardize = TRUE,
    nfolds = 10,
    subset = !test
  )
  
  # fit Elastic Net Regression for different lambdas
  cv_elasticnet <- cv.glmnet(
    as.matrix(train_dummy[, colnames(train_dummy) != "score"]),
    train_dummy$score,
    alpha = 0.5,
    standardize = TRUE,
    nfolds = 10,
    subset = !test
  )
  
  # extract the best lambdas for every shrinkage method
  best_lambda_lasso <- cv_lasso$lambda.min 
  best_lambda_ridge <- cv_ridge$lambda.min 
  best_lambda_elasticnet <- cv_elasticnet$lambda.min
  
  # refit Lasso regression using the best lambda
  best_model_lasso <- glmnet(
    as.matrix(train_dummy[, colnames(train_dummy) != "score"]),
    train_dummy$score,
    alpha = 1,
    lambda = best_lambda_lasso,
    subset = !test
  )
  
  # refit Ridge regression using the best lambda
  best_model_ridge <- glmnet(
    as.matrix(train_dummy[, colnames(train_dummy) != "score"]),
    train_dummy$score,
    alpha = 0,
    lambda = best_lambda_ridge,
    subset = !test
  )
  
  # refit Elastic Net regression using the best lambda
  best_model_elasticnet <- glmnet(
    as.matrix(train_dummy[, colnames(train_dummy) != "score"]),
    train_dummy$score,
    alpha = 0.5,
    lambda = best_lambda_elasticnet,
    subset = !test
  )
  
  # predict on the remaining folds using Lasso regression
  predict_lasso <- predict(
    best_model_lasso, 
    s = best_lambda_lasso,
    newx = as.matrix(train_dummy[, colnames(train_dummy) != "score"][test,])
  )
  
  # predict on the remaining folds using Ridge regression
  predict_ridge <- predict(
    best_model_ridge, 
    s = best_lambda_ridge,
    newx = as.matrix(train_dummy[, colnames(train_dummy) != "score"][test,])
  )
  
  # predict on the remaining folds using Elastic Net regression
  predict_elasticnet <- predict(
      best_model_elasticnet,
      s = best_lambda_elasticnet,
      newx = as.matrix(train_dummy[, colnames(train_dummy) != "score"][test,])
  )
  
  # MSE Lasso regression
  mse_matrix[i, 1] <- mean((
    train_dummy$score[test] - predict_lasso[, 1]) ^ 2
    )
  
  # MSE Ridge regression
  mse_matrix[i, 2] <- mean((
    train_dummy$score[test] - predict_ridge[, 1]) ^ 2
  ) 
  
  # MSE Elastic Net regression
  mse_matrix[i, 3] <- mean((
    train_dummy$score[test] - predict_elasticnet[, 1]) ^ 2
  ) 

}

# mean of the MSE’s for each method
apply(X = mse_matrix, 2, mean)
```

```{r}
#| label: Ridge plot

plot(cv_ridge)
```

The plot shows the different values for the logs of \lambda and their corresponding MSE's. The best \lambda turned out to be 0.966 (log(0.966) = -0.34).

## Regression Trees 

The Regression Tree model has been developed to utilize the tree models’ interpretability and graphical display feasibility. As the first step, a basic regression tree has been fit using rpart and visualized via rpart.plot. Looking at the error rate for different sizes of the tree, we concluded that the best size for this single tree would be either 4 or 8 terminal nodes (lowest x-val relative error). We performed additional hyperparameter tuning by creating a hypergrid, assessing different combinations of minsplit, maxdepth and cp values and listing top 5 instances with the lowest error rate. Then, we fit an optimal regression tree using parameter values of the best combination and calculate the MSE on the testing part of the training dataset: 1.19.

To improve the performance and reduce the high variance of a single tree model, 2 approaches to bagging have been implemented. Firstly, a simple bagged model using 25 bootstrap replications has been developed with the rmse/ntree balanced at 27 trees (also with more trees at 42). Moving forward, we decided to create a more advanced bagged model using caret in order to perform cross-validation and investigate the importance of variables across bagged trees. We used a 10-fold cross validation model resulting in 0.81 MSE which was a 0.38 improvement compared to the optimal single tree. Interestingly, we found out that absences played the most significant role in this model, followed by age.

```{r}
#| label: 80-20 split

# 80-20 split
set.seed(42)
ind <- sample(1:nrow(train_dummy), 0.8 * nrow(train_dummy))
train_dummy_train <- train_dummy[ind, ]
train_dummy_test <- train_dummy[-ind, ]
```

###  Basic regression tree

```{r}
#| label: Basic regression tree

tree1 <- rpart(
  formula = score ~ .,
  data    = train_dummy_train,
  method  = "anova"
)
```

```{r}
#| label: Tree visual

# Tree visual
rpart.plot(tree1)
```

```{r}
#| label: Tree size vs Error

# Tree size vs Error
plotcp(tree1)
```

```{r}
#| label: Tuning

# Tuning: creating hyperparameter grid
hyper_grid <- expand.grid(
  minsplit = seq(1, 30, 1),
  maxdepth = seq(1, 30, 1)
)
head(hyper_grid)

# 900 combinations
# nrow(hyper_grid)
```

```{r}
#| label: Iteration

# iterate through each combination
models <- list()

for (i in 1:nrow(hyper_grid)) {
  
  # get minsplit, maxdepth values at row i
  minsplit <- hyper_grid$minsplit[i]
  maxdepth <- hyper_grid$maxdepth[i]
  
  # train a model and store in the list
  models[[i]] <- rpart(
    formula = score ~ .,
    data    = train_dummy_train,
    method  = "anova",
    control = list(minsplit = minsplit, maxdepth = maxdepth)
  )
}
```

```{r}
#| label: Optimal cp

# function to get optimal cp
get_cp <- function(x) {
  min    <- which.min(x$cptable[, "xerror"])
  cp <- x$cptable[min, "CP"] 
}
```

```{r}
#| label: Minimal Error

# function to get minimum error
get_min_error <- function(x) {
  min    <- which.min(x$cptable[, "xerror"])
  xerror <- x$cptable[min, "xerror"] 
}
```

```{r}
#| label: Best 5 combinations

# Best 5 combinations
set.seed(42)

hyper_grid %>%
  mutate(
    cp    = purrr::map_dbl(models, get_cp),
    error = purrr::map_dbl(models, get_min_error)
  ) %>%
  arrange(error) %>%
  top_n(-5, wt = error)
```

```{r}
#| label: Optimal tree

# Opimal tree
# params based on previous results
optimal_tree <- rpart(
  formula = score ~ .,
  data    = train_dummy_train,
  method  = "anova",
  control = list(minsplit = 28, maxdepth = 15, cp = 0.01210821)
)
```

```{r}
#| label: MSE_

# assess MSE of the optimal tree on the testing split
pred <- predict(optimal_tree, newdata = train_dummy_test)
(RMSE(pred = pred, obs = train_dummy_test$score))^2
```

### Simple bagged model

```{r}
#| label: Simple bagged model

# train bagged model
bagged_tree1 <- bagging(
  formula = score ~ .,
  data    = train_dummy_train,
  coob    = TRUE
)
bagged_tree1
```

```{r}
#| label: Bagged model

# assess 10-50 bagged trees
ntree <- 10:50

# create empty vector to store OOB RMSE values
rmse <- vector(mode = "numeric", length = length(ntree))

for (i in seq_along(ntree)) {
  # reproducibility
  set.seed(42)
  
  # perform bagged model
  model <- bagging(
    formula = score ~ .,
    data    = train_dummy_train,
    coob    = TRUE,
    nbagg   = ntree[i]
  )
  # get OOB error
  rmse[i] <- model$err
}

plot(ntree, rmse, type = 'l', lwd = 2)
abline(v = 27, col = "red", lty = "dashed")
```

### Advanced bagged model

```{r}
#| label: Advanced bagged model

# bagging with caret

# reproducibility
set.seed(42)
# specify 10-fold cross validation
ctrl <- trainControl(method = "cv",  number = 10) 

# CV bagged model
bagged_cv <- train(
  score ~ .,
  data = train_dummy,
  method = "treebag",
  trControl = ctrl,
  importance = TRUE
)
```

```{r}
#| label: Results

# assess results
bagged_cv  
```

```{r}
#| label: Plot most important variables

# # Most important variables
plot(varImp(bagged_cv), 10)
```



### Random Forest Trees

We also decided on trying Random Forests with hyperparameter tuning. Random forests are bagged trees with feature sampling. Therefore, also the columns will be sampled.

For the hyperparameters, we used 

- different number of trees: In order to stabilise the error rate the number of trees need to be sufficiently large. With including more trees, one observes more robust and stable error estimates and variable importance measures but the running time increases. A rule of thumb is 10 times the number of features but with adjusting m and the node size, the number of trees may need to be adapted (Boehmke).
- different amount of variables chosen at each split ($m$): The amount of variables chosen at each split is selected as $\lfloor p/3 \rfloor$, where p is the number of features. But in practice m should be treated as a tuning parameter. Setting $m = p$ results in observing bagging decision trees (Hastie).
- different number of node size: The default values for the node size for regression is 5 but with wanting to reduce the runtime or if the data has many noisy predictors and in addition m is high, one can increase the node size (Boehmke).

For the grid search strategy, we used MSE as the performance metric and stopped looking for models, if the improvement is less than 0.01% over the last 10 models or overall stop after 5 minutes.

Doing 10-fold Cross Validation and doing hyperparameter grid search, we received a model with an MSE of 0.83.

```{r, eval=FALSE}
#| label: Random Forest grid search

# initiate h2o session
h2o.no_progress()

# maximum memory size in bytes
h2o.init(max_mem_size = "5g")  

# convert training data into h2o object 
h2o_train <- as.h2o(train_dummy) 

# hyperparameter grid for grid search
hyperparam_grid <- list(
  # number of trees
  ntrees = seq(50, 1000, 10), # rule of thumb: n.features * 10 = 690
  # amount of variables chosen at each split
  mtries = seq(3, 35, 2), # rule of thumb: floor(n.features / 3) = 23 (m = n.features would be bagging)
  # minimal node size
  min_rows = seq(4, 20, 1) # default: 5 for regression
)

# random grid search strategy 
search_criteria <- list(
  # random search of all the combinations of the hyperparameters 
  strategy = "RandomDiscrete", 
  # use MSE as the performance metric
  stopping_metric = "MSE",
  # stop if improvement is < 0.01% 
  stopping_tolerance = 0.0001, 
  # over the last 10 models
  stopping_rounds = 10, 
  # or stop search after 5 minutes
  max_runtime_secs = 60 * 5 
)

# perform grid search 
random_grid <- h2o.grid(
  algorithm = "randomForest",
  grid_id = "rf.random.grid",
  x = setdiff(colnames(train_dummy), "score"),
  y = "score",
  training_frame = h2o_train,
  hyper_params = hyperparam_grid,
  seed = 42,
  search_criteria = search_criteria
)

grid_res <- h2o.getGrid(
  grid_id = "rf.random.grid",
  sort_by = "mse",
  decreasing = FALSE
)
grid_res

# show best model
df_best <- h2o.getModel(grid_res@model_ids[[1]])
df_best

h2o.shutdown()
```

### XG Boost 

XGBoost, or Extreme Gradient Boosting, is a machine learning algorithm that uses an ensemble of decision trees to make predictions. It is a type of gradient boosting, which is a supervised learning algorithm that attempts to accurately predict a target variable by combining the estimates of a set of simpler, weaker models. XGBoost minimizes a regularized objective function which consists of the difference between target and predicted outputs and a penalty term model complexity. XGBoost works by building a sequence of decision trees, where each tree is trained to predict the residuals of the previous tree. This means that each tree learns to correct the errors of the previous tree, resulting in an increasingly accurate model. This process is repeated until the model reaches a stopping criterion, such as a maximum number of trees or a desired level of accuracy.

In order to get more sensitive results, hyper tuning is applied via tuneGrid parameter of the caret library. The parameter $\eta$ is added to shrink feature weights to make the boosting processing more controlled. min_child_weight refers to when tree partition should be stopped. The parameter $\gamma$ refers to minimum loss reduction. The selected values for these parameters could be optimized but it creates inefficient computational as well. We tried to find values having better MSE with speed computation.

Using XG Boost, we received an MSE of 0.79.

```{r modelling, warning=FALSE, message=FALSE, eval=FALSE}
#| label: XG Boost grid search

set.seed(42)
xgb_caret <- train(
  x = train_dummy[-3],
  y = train_dummy$score,
  method = "xgbTree",
  objective = "reg:squarederror",
  trControl = trainControl(
    method = "repeatedcv",
    number = 10,
    repeats = 2,
    verboseIter = TRUE
  ),
  tuneGrid = expand.grid(
    nrounds = c(500, 1000, 1500),
    eta = c(0.01, 0.1, 0.3),
    #eta = c(0.01,0.05),
    #max_depth = c(2,4,6),
    max_depth = c(2, 3, 5, 10),
    #colsample_bytree = c(0.5,1),
    colsample_bytree = 1,
    #subsample = c(0.5,1),
    subsample = 1,
    gamma = c(0),
    #min_child_weight = c(0,20),
    min_child_weight = 1
  )
)
```

```{r mse calculation, eval=FALSE}
#| label: MSE

pred_xgb_caret <- predict(xgb_caret, train_dummy[-3])
error_xgb_caret <- pred_xgb_caret - train_dummy$score
sqrt(mean(error_xgb_caret^2))
```

## KNN

K-Nearest Neighbors (KNN) is an machine learning algorithm that makes predictions by finding the ‘k’ nearest data points in the training dataset to a new data point and then classifying or predicting the new point based on the majority class of those neighbors. It is a simple and non-parametric algorithm but requires selecting the appropriate ‘k’ and distance metric for optimal performance.

Doing knn using grid search for k = {1, ..., 10}, using k = 8 performed best, i.e. it had the lowest MSE of 0.89.

```{r}
#| label: KNN

set.seed(42) 
trControl <- trainControl(method = "cv", number = 10)

# Train a k-nearest neighbors "KNN" model with different values of k.
model <- train(score ~ .,
               method     = "knn",
               tuneGrid   = expand.grid(k = 1:10),
               trControl  = trControl,
               metric     = "RMSE",
               data       = train_dummy)

# Calculate mean squared error (MSE) values.
mse <- model$results$RMSE^2
min(mse)
```



# Model comparison

To compare our models, we decided on doing 10-fold Cross-Validation which provides fast computation speed and is a very effective method to estimate the prediction error and the accuracy of the model. With using 10-fold Cross-Validation, the model is evaluated 10 times and each time another fold is selected as the test set and the rest of the folds are selected as the training set. This provides more robust understanding of the true expected test error.
Our team decided to select the best model based on the lowest MSE indicated by the 10-fold cross-validation. MSE quantifies the average squared difference between the predicted and actual values. The lower the MSE the better fit of the model to the data. MSE is a common and useful evaluation method that allows us to compare all our different models on the same standardized metric. When comparing models based on MSE, we are also aware to be cautious of overfitting. Provided training data was limited, therefore our models are likely to fit that training data too closely and perform slightly worse with unseen testing data.



# Chosen model

Based on the three criteria above, we concluded to move forward with the Ridge regression model. It has the lowest error rate (0.73 MSE). This model performed the best most likely due to its feature of doing well with data suffering from multicollinearity (our data has been affected by that because of the large number of parameters). Additionally, as Ridge regression is one of the variations of multiple-regression models, it provides clear estimates of the coefficients and can be easily explained and interpreted. 

```{r}
#| label: Final results

data.frame(
  model       = c("Ridge", "Advanced Bagged Models", "Random Forest", "XG Boost", "KNN"),
  MSE         = c(0.73, 0.81, 0.83, 0.79, 0.89)
)
```



# Final prediction

```{r}
#| label: Final prediction

# prediction on the test set
pred <- predict(
  best_model_ridge, 
  s = best_lambda_ridge,
  newx = as.matrix(test_dummy)
)
```

```{r,eval=FALSE}
#| label: Save predictions

# save the predictions
saveRDS(pred, "predictions.Rds")
```



