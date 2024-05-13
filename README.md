# Supervised Learning Competition

## Authors
- Adam Diamantidis
- Dimitrios Diamantidis

## Published
21-10-2023

## Overview
This project focuses on predicting student scores based on several predictors through various statistical and machine learning models. We conducted extensive data analysis, preprocessing, and applied multiple regression techniques to develop models that predict academic performance.

## Data Description
The dataset consists of 316 observations and 31 variables:
- **Categorical Variables:** 'school', 'sex', 'address', 'famsize', 'Pstatus', 'Mjob', 'Fjob', 'reason', 'guardian', 'schoolsup', 'famsup', 'paid', 'activities', 'nursery', 'higher', 'internet', 'romantic'.
- **Numeric Variables:** Includes age, study hours, and others not listed explicitly.
- **Statistics:** Average age of students is 17 years with a standard deviation of 13. Study hours range from 1 to 4 hours weekly, with a median of 2.03 hours.

## Key Insights from Data Analysis
- Gender differences in absences, especially at higher values.
- The impact of family size and parent's job on student outcomes.
- Correlation between study time and absences, score distribution differences by gender, and score variations by reasons for attending school.

## Data Transformation and Pre-processing
- Dummy coding was applied to categorical variables.
- Excluded certain dummy variables from the training set due to lack of presence in the test set.

## Models Description
- **Shrinkage Methods:** Applied Lasso, Ridge, and Elastic Net regression. Ridge regression provided the best results with an MSE of 0.73.
- **Regression Trees:** Explored simple and bagged regression tree models, optimizing the tree size and parameters to minimize MSE.
- **Random Forests:** Implemented with a focus on tuning the number of trees, variables per split, and node size.
- **XG Boost:** Utilized XGBoost with hyperparameter tuning for feature weight shrinkage and tree complexity control.
- **KNN:** Conducted grid search to find the optimal 'k' resulting in the lowest MSE.

## Best Performing Model
Ridge regression was chosen as the best model due to its performance and robustness against multicollinearity, indicated by the lowest MSE (0.73) among all models tested.

## Code Implementation
The project includes multiple scripts detailing data preprocessing, model fitting, and evaluations.
