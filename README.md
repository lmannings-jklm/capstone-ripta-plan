![Header Image](KP-aerial.png)
# Harvard Data Science Capstone: Evaluating the Operational and Equity Impacts of Providence Transit Center Relocation

## 1. Project Overview
This project is focused on evaluating the overall effectiveness of a proposed plan to relocate transit hub in the City of Providence from Kennedy Plaza to a site adjacent to the Providence train station.

The Rhode Island Public Transit Authority (RIPTA) is currently evaluating a Joint Development Project to relocate Providence's central transit hub from Kennedy Plaza (KP) to a new facility adjacent to Providence Station at Park Row West and Francis Street (PRW-FS). While this relocation aims to modernize infrastructure and co-locate bus and rail services, pushing the primary transit hub to the periphery of the downcity core fundamentally alters the operational geometry of the regional transit network.

This study executes a two-pronged data science project to analyze the operational, financial, and socioeconomic impacts of this proposed hub relocation. Utilizing extensive publicly available datasets—including 12 months of high-fidelity Computer-Aided Dispatch and Automatic Vehicle Location (CAD/AVL) event logs, static General Transit Feed Specification (GTFS) schedules, and U.S. Census Bureau American Community Survey (ACS) demographics—the analysis establishes an empirical baseline of the existing network. To capture the complex traffic bottlenecks and nonlinear frequency thresholds, the study applies asvanced machine learning techniques, extending beyond standard linear regression to model the relocation and predict how delays will ripple through the transit network.

---

## 2. Key Questions
- **Does extending RIPTA bus routes coming from all points south, west, north, and east to PRW-FS structurally increase the temporal driving delays, vehicle service hours, and marginal operating costs?**
- **Does relocating the transit hub away from KP to PRW-FS disproportionately increase walking travel time penalties and steep slope elevation burdens for vulnerable, transit-dependent populations compared to non-vulnerable populations?**

---

## 3. Installation and Setup

### Codes and Resourses

- **Editor:** RStudio 2026.10.1 Build 239
- **R Version:** R version 4.5.0
---
### R Packages Used
The following libraries and options are required to complete the assignment:
- `tidyverse`  Core data manipulation (dplyr, stringr, lubridate, ggplot2, etc.)
- `readr`  reads table data into R
-  `skimr`  Provides descriptive statistics and data quality summaries supporting tidyverse
- `stringi`  R package for efficient string processing
- `knitr`    Power R Markdown by handling the execution of embedded R code  
- `kableExtra`  Library that contains functions for working with date-time data
- `lubridate`  Library that contains functions for working with date-time data
- `scales`  Provides functions for human readable labels for axes and legends
- `patchwork`  Provides support for multiplot layouts
- `data.table`  Enhanced data frame capabilities
- `latex2exp`   Converts LaTeX syntax to plotmath notation
- `ggforce`  Extends ggplot2 by adding extra geometric objects
- `parallel`  Supports mult-core parallel computing
- `broom`  Convert statistical parameters into tibbles
- `grid`  Contains primitive graphic functions for ggplot2.
- `ggrepel`  Provides geoms to repel overlapping text labels.
- `osrm`   High performance routing engine.
- `caret`   Provides machine learning algorithms.
- `rosm`   Plot open source maps.
- `ggspatial`   Extends ggplot2 with cartographic plot tools.
- `prettymapr`   Enables automated map formatting.     
---

## 4. Data

### Source Data


---

### Data Preprocessing
The source data is not presumed to meet [**tidy data** standards](https://cran.r-project.org/web/packages/tidyr/vignettes/tidy-data.html). Additional data wrangling will likely be required.

---

## 5. Project Structure

Project Repository structure is outlined below.
``` text
ª   README.md
ª   
+---data
+---images
+---notebook
ª   ª   capstone_movielens.html
ª   ª   capstone_movielens.pdf
ª   ª   capstone_movielens.qmd
ª   ª   capstone_movielens.Rmd
+---scripts
        01_generate_datasets.R
        02_movilens_project.R
```
---
## 6. Results and Evaluation

See the **Results** and **Conclusion** sections of the capstone report, `capstone_movielens.pdf`.

---
## 7. Acknowledgements / References



---

