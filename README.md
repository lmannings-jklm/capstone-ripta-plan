![Header Image](KP-aerial.png)
# Harvard Data Science Capstone: Evaluating the Operational and Equity Impacts of Providence Transit Center Relocation

## 1. Project Overview
This project is focused on evaluating the overall effectiveness of a proposed plan to relocate transit hub in the City of Providence from Kennedy Plaza to a site adjacent to the Providence train station.

The Rhode Island Public Transit Authority (RIPTA) is currently evaluating a Joint Development Project to relocate Providence's central transit hub from Kennedy Plaza (KP) to a new facility adjacent to Providence Station at Park Row West and Francis Street (PRW-FS). While this relocation aims to modernize infrastructure and co-locate bus and rail services, pushing the primary transit hub to the periphery of the downcity core fundamentally alters the operational geometry of the regional transit network.

This study executes a two-pronged data science project to analyze the operational, financial, and socioeconomic impacts of this proposed hub relocation. Utilizing extensive publicly available datasets—including 12 months of high-fidelity Computer-Aided Dispatch and Automatic Vehicle Location (CAD/AVL) event logs, static General Transit Feed Specification (GTFS) schedules, and U.S. Census Bureau American Community Survey (ACS) demographics—the analysis establishes an empirical baseline of the existing network. To capture the complex traffic bottlenecks and nonlinear frequency thresholds, the study applies asvanced machine learning techniques, extending beyond standard linear regression to model the relocation and predict how delays will ripple through the transit network.

---

## 2. Key Questions
- **What are the primary drivers of schedule delay within the existing Providence transit network, and how will the physical relocation to Park Row West impact overall operational reliability?**
- **Does relocating the transit hub from KP to PRW-FS create a disparate impact that disproportionately degrades transit access for vulnerable, transit-dependent populations?**

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

## 4. Primary Data Summary

### General Transit Feed Specification(GTFS)
GTFS is an Open Standard used to distribute relevant information about transit systems to riders. It allows public transit agencies to publish their transit data in a format that can be consumed by a wide variety of software applications.

### RIPTA CAD/AVL Historical Archive
To overcome the limitations of algorithmically interpolated static schedules and the API rate constraints of streaming GTFS-Realtime feeds, a 12-month contiguous historical archive of CAD/AVL transit event records was acquired via a formal Rhode Island Access to Public Records Act (APRA) request. This dataset provides the high-fidelity event precision requires for econometric modeling, logging scheduled vs. actual vehicle movements, schedule deviation in seconds, and high-precision GPS coordinates for decision timepoint isolation across the downcity network.

### RIPTA Kennedy Plaza Transfer Data & Passenger Counts
A RIPTA public outreach survey to a total of 4,438 individuals in support of the project to capture public engagement feedback. The surveys documented origin zip codes and trip purposes. While it would be advantageous to use this data to estimate the proportion of riders that terminate their trip in Downcity Providence from a particular bus route, this data was not captured in the survey and zip code is not specific enough to infer a specific route. Additionally, the survey sample was not assessed to be representative of all daily RIPTA riders, as it was only distributed online and at public hearings, and included about 15% of non-riders or infrequent riders.

### U.S. Census Bureau Databases
U.S Census Bureau block-group demographic data can be pulled via the American Community Survey (ACS) 5-Year estimates. This data—specifically tracking median household income, race and ethnicity, zero-vehicle households, civilian ambulatory disability, and senior populations— is utilized to parameterize the equity evaluation and classify neighborhoods into the study's Transit-Dependent and Mobility-Challenged vulnerability tiers.

### RIGIS Digital Elevation Models (DEM) & Spatial Layers
Elevation datasets from the Rhode Island Geographic Information System (RIGIS) paired with street / parcel boundaries to construct walking buffers and compute slope gradients and effort weighted walking speeds.


---

### Data Preprocessing
The source data is not presumed to meet [**tidy data** standards](https://cran.r-project.org/web/packages/tidyr/vignettes/tidy-data.html). Additional data wrangling will likely be required.

---

## 5. Project Structure

Project Repository structure is outlined below.
``` text
├── capstone-ripta-plan.Rproj
├── data
│   ├── caret_feature_importance.csv
│   ├── caret_holdout_test_metrics.csv
│   ├── caret_train_cv_metrics.csv
│   ├── gtfs_merged_1yr
│   │   ├── calendar.txt
│   │   ├── routes.txt
│   │   ├── route_timepoints.txt
│   │   ├── shapes.txt
│   │   ├── stops.txt
│   │   ├── stop_times.txt
│   │   └── trips.txt
│   ├── gtfs_raw_1yr
│   │   └── RIPTA-GTFS.zip
│   ├── kp_route_summary.csv
│   ├── mc_pedestrian_results_bidirectional.csv
│   ├── model_a_multivariable_coefficients_v3.csv
│   ├── objects
│   ├── ripta-simulated-routes.csv
│   ├── ripta_avl_1yr_log.csv
│   ├── ripta_bidirectional_filtered.csv
│   ├── ripta_kp_final_dataset.csv
│   ├── ripta_operational_cost.csv
│   └── scratch
├── images
│   └── KP-aerial.png
├── notebook
│   ├── capstone-ripta.html
│   ├── capstone-ripta.pdf
│   ├── capstone-ripta.qmd
│   ├── footnote-references
│   ├── images
│   └── tables
├── README.md
└── scripts
    ├── eda
    ├── old
    ├── test_03_model_a_operational_delay.R
    ├── test_04_fit_caret_operational_delay.R
    ├── test_05_generate_op_costs.R
    ├── test_06_equity_pedestrian_impact_sim.R
    └── tools
```
---
## 6. Results and Evaluation

See the **Conclusions & Results** sections of the capstone report, `capstone_ripta.pdf`.
---
## 7. Data & Code Availability

The processed datasets generated and analyzed during this project, along with the complete R processing scripts, are available in the project repository at <https://github.com/lmannings-jklm/capstone-ripta-plan>.
All third-party spatial and demographic inputs can be retrieved directly from their respective public portals.

---
## 8. Acknowledgements

Extended thanks are due to the HarvardX Data Science program for providing the foundation and motivation to select and complete this project. Additional thanks go to my family and several professional colleagues who encouraged me to focus on a problem with meaningful impacts on my community. I gratefully acknowledge RIPTA Legal Services and agency data administrators for fulfilling this public records request and providing access to historical Computer-Aided Dispatch and Automatic Vehicle Location (CAD/AVL) archives.

### Disclosure of Artificial Intelligence Usage

During the preparation of this work, the author utilized Google Gemini resources (*specifically NotebookLM and Gemini 3.1 Pro*) to assist with preliminary research, language editing, citation formatting, analytical brainstorming, and code review/troubleshooting. All AI-generated outputs, analyses, and code suggestions were critically reviewed, verified, and edited by the author. Every reference cited has been reviewed for appropriateness and independently verified against the primary sources.

---
## 9. Data Attribution & Disclaimer

### Data Attribution
The empirical analyses presented in this report utilize operational transit data provided by the Rhode Island Public Transit Authority (RIPTA) pursuant to a formal public records request under the Rhode Island Access to Public Records Act, supplemented by public General Transit Feed Specification (GTFS) and GTFS-Realtime feeds published by the agency. Demographic, elevation, and street-network inputs are sourced from the U.S. Census Bureau American Community Survey (ACS), the Rhode Island Geographic Information System (RIGIS), and OpenStreetMap.

### Disclaimer of Affiliation and Views

This report, including all underlying analytical models, statistical interpretations, geospatial evaluations, visualizations, findings, and recommendations, is the independent academic work product of the author. This report does not contain or reflect the official views, policies, opinions, endorsements, or work product of RIPTA, the State of Rhode Island, or any of their respective agencies or affiliates. All analyses, models, and conclusions presented herein are solely based on the empirical data and public documentation provided by or obtained from RIPTA, evaluated independently by the author. RIPTA assumes no responsibility or liability for any errors, omissions, interpretations, conclusions, or downstream applications derived from the data used in this study.

