![Header Image](images/KP-aerial.png)
# Harvard Data Science Capstone: Evaluating the Operational and Equity Impacts of Providence Transit Center Relocation

## 1. Project Overview
This project evaluates the operational, financial, and equity impacts of a proposed plan to relocate the central transit hub in the City of Providence from Kennedy Plaza to a site adjacent to the Providence train station.

The Rhode Island Public Transit Authority (RIPTA) is proposing a public-private partnership to move Providence's central bus hub out of downtown's Kennedy Plaza (KP) to a new site beside Providence Station at Park Row West and Francis Street (*hereafter referred to as Park Row West*). While moving this hub would modernize aging infrastructure and connect buses directly to commuter rail, shifting the system's anchor to the northern edge of Downcity Providence fundamentally changes how buses—and riders—move through the city.

This study evaluates the operational, financial, and rider-access impacts of that move using 12 months of actual RIPTA Computer-Aided Dispatch and Automatic Vehicle Location (CAD/AVL) bus-tracking records (*covering more than 335,000 inbound trips*), published General Transit Feed Specification (GTFS) bus schedules, U.S. Census Bureau American Community Survey (ACS) data, and local elevation maps. Combining historical statistical modeling with machine learning, this study measures how extended routes add to everyday travel times—and uncovers hidden **rush-hour tipping points**, where crowded streets, tight turns, and back-to-back buses cause delays to snowball across the network.

## 2. Key Questions
- **What causes bus delays in downtown Providence today, and how will extending routes to Park Row West affect on-time reliability and operating costs?**
- **Does moving the hub away from Kennedy Plaza create an inequitable burden (*'disparate impact'*) that hits low-income, senior, and mobility-challenged riders hardest?**

## 3. Quick Start: Installation & Reproducibility

### Prerequisites
* R (>= 4.5), RStudio, and TinyTeX (for PDF rendering)

### 1. Clone the Repository
**Option A — In RStudio (Recommended):**
1. Go to **File → New Project → Version Control → Git**.
2. Paste the Repository URL: `https://github.com/lmannings-jklm/capstone-ripta-plan.git`
3. Click **Create Project**. RStudio will clone the exact folder structure and open `capstone-ripta-plan.Rproj` automatically.

**Option B — Command Line:**
```bash
git clone [https://github.com/lmannings-jklm/capstone-ripta-plan.git](https://github.com/lmannings-jklm/capstone-ripta-plan.git)
cd capstone-ripta-plan
```
Then double-click `capstone-ripta-plan.Rproj` to open the project in RStudio.

### 2. Restore the Exact R Package Environment
In the RStudio Console, run:
```r
install.packages("renv") # if not already installed
renv::restore()
```
This installs the exact package versions recorded in `renv.lock` into an isolated project library without affecting your global R setup.

### 3. Run Scripts or Render the Report
* **Render the full report:** Open `notebook/capstone-ripta.qmd` (or `capstone-ripta.Rmd`) and click **Render** / **Knit**. All processed datasets required for rendering are already included in `data/`.
* **Run individual scripts:** Execute any script in `scripts/` or `scripts/eda/` directly from the RStudio project root (all paths are relative to the `.Rproj` directory).
* **Full raw pipeline (optional):** To re-run raw 1-year AVL ingestion from scratch, pull the ~924 MB log directly into `data/` from the RStudio Console:
```r
source("scripts/tools/download_raw_avl.R")
```
*(Alternatively, download `ripta_avl_1yr_log.csv` manually from the [Releases](https://github.com/lmannings-jklm/capstone-ripta-plan/releases) page and place it in `data/`.)*

## 4. Primary Data Summary

### General Transit Feed Specification (GTFS)
GTFS is an open standard used to distribute authoritative transit schedule information (*route paths, trips, bus stops, and arrival/departure timetables*) to riders and analytical applications.

---
### RIPTA CAD/AVL Historical Archive
Published timetables estimate intermediate stop times mathematically, while public live-tracking feeds (*GTFS-Realtime*) restrict how much historical data can be downloaded. To build an exact four-season record, we obtained a full 12-month archive of internal Computer-Aided Dispatch and Automatic Vehicle Location (*CAD/AVL*) logs via a Rhode Island Access to Public Records Act (APRA) request. These records log *scheduled vs. actual* bus arrivals to the second alongside precise GPS coordinates—allowing us to measure corridor delays just before buses hit downtown hub congestion.

---
### RIPTA Kennedy Plaza Transfer Data & Passenger Counts
Next Wave Rhode Island Partners surveyed 4,438 people during public outreach, recording home ZIP codes and trip purposes. However, the survey did not record which specific bus routes respondents rode, and ZIP codes are too broad to tie responses to individual lines. Moreover, because the survey was distributed only online and at public meetings—and included roughly 15% non-riders and infrequent riders—it does not represent daily bus commuters as a whole. To evaluate downtown rider displacement, this survey baseline is combined with route-level ridership models and external Automated Passenger Counter (APC) benchmarks.

---
### U.S. Census Bureau Databases
U.S. Census Bureau block-group demographic data was extracted via the American Community Survey (ACS) 5-Year estimates. This data—specifically tracking median household income, race and ethnicity, zero-vehicle households, residents with walking disabilities, and senior populations—is used to define the study's Transit-Dependent and Mobility-Challenged vulnerability tiers.

---
### RIGIS Digital Elevation Models (DEM) & Spatial Layers
Elevation datasets from the Rhode Island Geographic Information System (RIGIS) were paired with street and parcel boundaries to map quarter-mile walking zones, street steepness, and effort-weighted walking speeds.

---
### Data Preprocessing
Because raw transit event logs, spatial rasters, and Census tables do not natively conform to [**tidy data** standards](https://cran.r-project.org/web/packages/tidyr/vignettes/tidy-data.html), extensive preprocessing—including trip-level deduplication, coordinate re-projection into Rhode Island State Plane feet, and route-volume demographic weighting—was executed prior to statistical modeling.

## 5. Project Structure

The project repository structure is outlined below:
```text
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
    ├── test_03_model_a_operational_delay.R
    ├── test_04_fit_caret_operational_delay.R
    ├── test_05_generate_op_costs.R
    ├── test_06_equity_pedestrian_impact_sim.R
    └── tools
```

## 6. Results and Evaluation

Key empirical findings from the study include:
- **Higher Operating Costs and Fleet Strain:** Relocating all routes to Park Row West adds a net **2,336 Vehicle Revenue Hours per year** (*~6.4 hours/day*), requiring **2 to 3 additional peak buses** and **$394,279 in net annual operating costs** simply to maintain existing schedules.
- **A Universal 13.4-Minute Transfer Penalty:** Closing Kennedy Plaza creates an 1,820-foot (0.34-mile) uphill gap to the new hub, adding an average of **13.37 minutes** (*nearly 13.5 minutes*) each way across walking and shuttle trips for displaced downtown riders.
- **A Geographic Divide with Heavy Practical Equity Costs:** While select Northern routes save distance and cost, **19 of the 30 delayed corridors** serve Transit-Dependent and Mobility-Challenged neighborhoods along the East, South, and West—placing the heaviest practical burden on car-free, elderly, and disabled commuters.

For full methodology, statistical evaluations, and policy recommendations, see the **Executive Summary**, **Analysis & Results (Section 5)**, and **Conclusion / Recommendations (Section 6)** of the complete report in `notebook/capstone-ripta.pdf`.

## 7. Data & Code Availability

The processed datasets generated and analyzed during this project, along with the complete R processing scripts, are available in the project repository at <https://github.com/lmannings-jklm/capstone-ripta-plan>. All third-party spatial and demographic inputs can be retrieved directly from their respective public portals, and documentation for reproducing the RIPTA CAD/AVL public records archive is provided in the repository.

## 8. Acknowledgements

Special thanks go to the HarvardX Data Science program for providing the foundation and motivation to select and complete this project. Additional thanks go to my family and several professional colleagues who encouraged me to focus on a problem with meaningful impacts on my community. I gratefully acknowledge RIPTA Legal Services and agency data administrators for fulfilling this public records request and providing access to historical Computer-Aided Dispatch and Automatic Vehicle Location (CAD/AVL) archives.

---
### Disclosure of Artificial Intelligence Usage

During the preparation of this work, the author utilized Google Gemini resources (*specifically NotebookLM and Gemini 3.1 Pro*) to assist with preliminary research, language editing, citation formatting, analytical brainstorming, and code review/troubleshooting. All AI-generated outputs, analyses, and code suggestions were critically reviewed, verified, and edited by the author. Every reference cited has been reviewed for appropriateness and independently verified against the primary sources.

## 9. Data Attribution & Disclaimer

### Data Attribution
The empirical analyses presented in this report utilize operational transit data provided by the Rhode Island Public Transit Authority (RIPTA) pursuant to a formal public records request under the Rhode Island Access to Public Records Act, supplemented by public General Transit Feed Specification (GTFS) and GTFS-Realtime feeds published by the agency. Demographic, elevation, and street-network inputs are sourced from the U.S. Census Bureau American Community Survey (ACS), the Rhode Island Geographic Information System (RIGIS), and OpenStreetMap.

---
### Disclaimer of Affiliation and Views

This report, including all underlying analytical models, statistical interpretations, geospatial evaluations, visualizations, findings, and recommendations, is the independent academic work product of the author. This report does not contain or reflect the official views, policies, opinions, endorsements, or work product of RIPTA, the State of Rhode Island, or any of their respective agencies or affiliates. All analyses, models, and conclusions presented herein are solely based on the empirical data and public documentation provided by or obtained from RIPTA, evaluated independently by the author. RIPTA assumes no responsibility or liability for any errors, omissions, interpretations, conclusions, or downstream applications derived from the data used in this study.
