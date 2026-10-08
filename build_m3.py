import os, docx
from docx.shared import Inches, Pt, RGBColor
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.table import WD_TABLE_ALIGNMENT

doc = docx.Document()

# Page Margins
for section in doc.sections:
    section.top_margin = Inches(0.7)
    section.bottom_margin = Inches(0.7)
    section.left_margin = Inches(0.75)
    section.right_margin = Inches(0.75)

# Title
title_p = doc.add_paragraph()
title_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
run_t = title_p.add_run('AI-Powered Environmental Intelligence System for Air Quality Prediction and Smart Mobility Recommendations\n')
run_t.font.name = 'Calibri'
run_t.font.size = Pt(16)
run_t.font.bold = True
run_t.font.color.rgb = RGBColor(15, 23, 42)

sub_p = doc.add_paragraph()
sub_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
run_sub = sub_p.add_run('Complete Project Work Summary – Module 3 / Final Milestone Submission\n')
run_sub.font.name = 'Calibri'
run_sub.font.size = Pt(13)
run_sub.font.bold = True
run_sub.font.color.rgb = RGBColor(2, 132, 199)

# Metadata
meta_p = doc.add_paragraph()
meta_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
run_meta = meta_p.add_run('Intern Name: Vaishnavi R Honnagudi  |  Domain: Artificial Intelligence  |  Institution: KLE Technological University, Hubballi\nGitHub Branch: Vaishnavi-R-H\n')
run_meta.font.name = 'Calibri'
run_meta.font.size = Pt(10)
run_meta.font.italic = True
run_meta.font.color.rgb = RGBColor(100, 116, 139)

def add_heading(text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(14)
    p.paragraph_format.space_after = Pt(4)
    run = p.add_run(text)
    run.font.name = 'Calibri'
    run.font.size = Pt(12.5)
    run.font.bold = True
    run.font.color.rgb = RGBColor(15, 23, 42)
    return p

def add_bullet(title, desc):
    p = doc.add_paragraph(style='List Bullet')
    p.paragraph_format.space_before = Pt(2)
    p.paragraph_format.space_after = Pt(2)
    r1 = p.add_run(title + ': ')
    r1.font.name = 'Calibri'
    r1.font.size = Pt(10)
    r1.font.bold = True
    r2 = p.add_run(desc)
    r2.font.name = 'Calibri'
    r2.font.size = Pt(10)

def add_para(text):
    p = doc.add_paragraph()
    p.paragraph_format.space_before = Pt(3)
    p.paragraph_format.space_after = Pt(4)
    run = p.add_run(text)
    run.font.name = 'Calibri'
    run.font.size = Pt(10)
    return p

def add_single_image(img_path, caption):
    if not os.path.exists(img_path):
        print(f'Warning: {img_path} not found')
        return
    p = doc.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    p.paragraph_format.space_before = Pt(6)
    p.paragraph_format.space_after = Pt(2)
    run = p.add_run()
    run.add_picture(img_path, width=Inches(2.7))
    
    cap_p = doc.add_paragraph()
    cap_p.alignment = WD_ALIGN_PARAGRAPH.CENTER
    cap_p.paragraph_format.space_before = Pt(0)
    cap_p.paragraph_format.space_after = Pt(8)
    c_run = cap_p.add_run(f'Figure: {caption}')
    c_run.font.name = 'Calibri'
    c_run.font.size = Pt(9)
    c_run.font.italic = True
    c_run.font.color.rgb = RGBColor(100, 116, 139)

def add_dual_images(img1_path, cap1, img2_path, cap2):
    table = doc.add_table(rows=2, cols=2)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    for row in table.rows:
        for cell in row.cells:
            cell.width = Inches(3.2)
            
    # Row 0: Images
    p1 = table.rows[0].cells[0].paragraphs[0]
    p1.alignment = WD_ALIGN_PARAGRAPH.CENTER
    if os.path.exists(img1_path):
        p1.add_run().add_picture(img1_path, width=Inches(2.65))
        
    p2 = table.rows[0].cells[1].paragraphs[0]
    p2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    if os.path.exists(img2_path):
        p2.add_run().add_picture(img2_path, width=Inches(2.65))
        
    # Row 1: Captions
    c1 = table.rows[1].cells[0].paragraphs[0]
    c1.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r1 = c1.add_run(f'Figure: {cap1}')
    r1.font.name = 'Calibri'
    r1.font.size = Pt(9)
    r1.font.italic = True
    r1.font.color.rgb = RGBColor(100, 116, 139)
    
    c2 = table.rows[1].cells[1].paragraphs[0]
    c2.alignment = WD_ALIGN_PARAGRAPH.CENTER
    r2 = c2.add_run(f'Figure: {cap2}')
    r2.font.name = 'Calibri'
    r2.font.size = Pt(9)
    r2.font.italic = True
    r2.font.color.rgb = RGBColor(100, 116, 139)
    
    # Extra spacing
    sp = doc.add_paragraph()
    sp.paragraph_format.space_before = Pt(0)
    sp.paragraph_format.space_after = Pt(4)

# 1. Project Goal & Milestone 3 Scope
add_heading('1. Project Goal & Milestone 3 Scope')
add_para('Building upon the deep learning forecasting foundation (Milestone 1) and the spatial interpolation API and web prototype (Milestone 2), Milestone 3 completes the end-to-end deployment of the system. This milestone delivers a fully functional, cross-platform Flutter Mobile Application (airsense_mobile) tailored exclusively for Delhi NCR. It introduces real-time zone switching, an interactive 24-hour predictive curve studio, hyper-local health and activity guidance, smart mobility route comparisons, persistent session history, and full production repository stabilization.')

# 2. End-to-End System Architecture
add_heading('2. End-to-End System Architecture')
add_bullet('Mobile Client (Flutter)', 'Multi-tab responsive application running on Android/iOS with custom animated navigation, fl_chart interactive curve graphics, and OpenStreetMap rendering.')
add_bullet('Web Client (React + Vite)', 'Synchronized web dashboard delivering desktop-class atmospheric telemetry, station-level lookups, and route exposure heatmaps.')
add_bullet('AI Inference Engine', 'Trained Long Short-Term Memory (LSTM) recurrent neural network running on GPU-accelerated infrastructure, capturing diurnal temperature inversions and multi-pollutant sequential trends with 96.3% test accuracy (R^2 = 0.995).')
add_bullet('Spatial IDW Service', 'FastAPI microservice executing Inverse Distance Weighting across 38 Delhi DPCC/CPCB monitoring stations to estimate hyper-local air quality at any street coordinate.')
add_bullet('Telemetry Pipeline', 'Continuous real-time meteorological ingestion (OpenWeatherMap, Open-Meteo) and transit duration sampling (OpenRouteService).')

# 3. Authentication & Onboarding
add_heading('3. Authentication & Onboarding')
add_para('The application incorporates a streamlined authentication layer supporting both registered users and instant access:')
add_bullet('Dual Authentication Modes', 'Integrates Firebase Authentication for email/password registration alongside an instant One-Tap Guest Mode to eliminate barriers for quick checks.')
add_bullet('Session Persistence', 'Local tokens and user IDs are preserved to personalize recommendations and retain search history across app launches.')
add_single_image('LoginPage.png', 'AirSense Authentication & Guest Mode Access Screen')

# 4. Flutter Mobile Application Implementation
add_heading('4. Flutter Mobile Application Implementation (airsense_mobile)')
add_para('The mobile application is structured around a 4-tab responsive shell designed to provide seamless mobility and health awareness for Delhi commuters:')
add_bullet('Tab 1 - Live AQI Dashboard', 'Displays Delhi NCR regional metrics, DPCC status badge, zone switching pills, 8-factor microclimate sensor grid, 24-hour forecast curve studio, pollutant safety bars, and lifestyle guidance.')
add_bullet('Tab 2 - Pollution Map & Mobility', 'Interactive map view powered by flutter_map and OpenStreetMap. Supports location pinpointing, current GPS acquisition, and route-planning mode with pre-configured Quick Delhi Routes.')
add_bullet('Tab 3 - Saved History', 'Chronological log of past location checks and route exposure calculations, displaying AQI score badges, categories, location labels, and relative timestamps.')
add_bullet('Tab 4 - Health Profile & Settings', 'Personalization portal allowing users to set their demographic sensitivity category (Infant, Child, Adult, Elder) and specify personal health context (e.g., asthma, allergies) that dynamically recalibrates public health advisories.')

# 5. Delhi Zone-Specific Real-Time Microclimate Monitoring
add_heading('5. Delhi Zone-Specific Real-Time Microclimate Monitoring')
add_para('Air quality in Delhi is heavily influenced by localized terrain and emission sources. Milestone 3 implements instantaneous zone-level switching across 4 calibrated representative corridors:')
add_bullet('Central Delhi (Connaught Place / Mandir Marg)', 'Commercial and administrative green belt. Baseline AQI: ~135 (Moderate), Temperature: 27.5°C, high UV index, and urban heat factors.')
add_bullet('East Delhi (Anand Vihar DPCC Hotspot)', 'Heavy transit terminal and industrial border zone. Baseline AQI: ~245 (Poor), Temperature: 29.0°C, dense smog, reduced visibility (2.5 km), and high PM2.5/PM10 concentrations.')
add_bullet('South Delhi (R.K. Puram / Hauz Khas)', 'Residential and institutional green corridor. Baseline AQI: ~118 (Satisfactory/Moderate), Temperature: 26.5°C, and favorable ventilation.')
add_bullet('North Delhi (Wazirpur Industrial Area)', 'Industrial manufacturing corridor. Baseline AQI: ~185 (Moderate/Poor), Temperature: 28.0°C, elevated SO2 and industrial particulates.')
add_para('Switching zones automatically updates all 8 atmospheric sensor parameters (Feels Like, Humidity, Wind Vector, UV Index, Visibility, Pressure, Cloud Cover, Precipitation) and recalculates all pollutant progress bars against CPCB national standards.')
add_dual_images('Dashboard.png', 'Live AQI Dashboard — Central Delhi (Connaught Place)', 'home page.png', 'Live AQI Dashboard — East Delhi (Anand Vihar Hotspot)')

# 6. Microclimate Atmospheric Condition Sensors
add_heading('6. Atmospheric Condition Sensor Grid')
add_para('The dashboard features an 8-factor microclimate telemetry grid that correlates atmospheric conditions with pollution dispersion:')
add_bullet('Feels Like & Humidity', 'Evaluates perceived temperature against relative humidity, highlighting urban heat island effects and moisture-induced smog binding.')
add_bullet('Wind Vector & Speed', 'Tracks dispersion potential (e.g. 11.0 km/h WNW), identifying stagnant pockets that trap vehicular exhaust.')
add_bullet('Optical Visibility & UV Index', 'Displays dust haze density in kilometers and UV radiation levels driving ground-level ozone formation.')
add_bullet('Pressure & Precipitation', 'Barometric surface pressure and rainfall tracking (evaluating natural wet deposition scrubbing).')
add_single_image('whether.png', 'Delhi Atmospheric Conditions & Real-Time Microclimate Sensor Grid')

# 7. Dynamic 24-Hour Predictive Forecast Curve Studio
add_heading('7. Dynamic 24-Hour Predictive Forecast Curve Studio (fl_chart)')
add_para('A major innovation in Milestone 3 is the dynamic, forward-looking 24-hour predictive forecast studio:')
add_bullet('Dynamic Real-Time Clock Integration', 'The timeline dynamically binds to the device clock (DateTime.now()), generating seamless hour progressions (e.g., Now -> 5 PM -> 6 PM -> 7 PM -> 6 AM -> 2 PM) rather than static templates.')
add_bullet('Diurnal Inversion Modeling', 'Accurately projects Delhi’s diurnal pollution dynamics: early morning inversion peaks (5:00 AM – 7:00 AM) where cold surface air traps emissions, and midday solar dispersion (1:00 PM – 4:00 PM) where solar heating lifts ground-level smog.')
add_bullet('Peak & Lowest AQI Chips', 'Automatically computes and highlights the predicted daily peak (e.g., Peak: 245 AQI at 6 AM) and lowest exposure window to help users plan outdoor activities safely.')
add_bullet('Dynamic Severity Curves', 'Smooth Bezier line chart that dynamically transitions from yellow (Moderate) to deep orange/red (Poor/Severe) based on peak forecast severity.')
add_bullet('Dual Graph Modes', 'Instant toggle between 24h AQI Curve and Weather & Temp trends, synchronized with horizontal forecast capsules underneath the chart.')
add_single_image('forecast.png', '24-Hour Dynamic Pollution & Weather Prediction Curve Studio with Peak/Lowest Chips')

# 8. Hyper-Local Health & Lifestyle Advisory Engine
add_heading('8. Hyper-Local Health & Lifestyle Advisory Engine')
add_para('Replaced static, one-size-fits-all recommendations with a context-aware advisory engine tailored to Delhi’s specific environmental risks:')
add_bullet('Outdoor Exercise Advisories', 'Recommends morning workout timings, shifting to indoor gyms when AQI > 200, and warns against jogging near the Anand Vihar ISBT and Ghazipur border.')
add_bullet('Home Ventilation Protocols', 'Instructs users when to seal exterior windows (night and early morning) and identifies optimal afternoon ventilation windows (1:00 PM – 4:00 PM) with HEPA purifier guidance.')
add_bullet('Mask Requirements', 'Enforces strict N95/FFP2 protective mask recommendations when fine particulate concentration exceeds safe thresholds.')
add_bullet('Demographic Sensitivity Calibration', 'Advisories automatically scale based on the active user profile (Infant, Child, Adult, Elder) and recorded respiratory conditions.')
add_single_image('health-advisory.png', 'Hyper-Local Delhi Health & Activity Guidance Advisory Cards')

# 9. Smart Mobility & Route Exposure Recommendations
add_heading('9. Smart Mobility & Clean Route Recommendations')
add_para('Integrated live road routing with spatial interpolation to evaluate commuting risk across Delhi:')
add_bullet('Route Geometry & Point Sampling', 'Fetches actual road geometry via OpenRouteService and samples coordinates at 2.0 km intervals.')
add_bullet('Cumulative AQI Exposure', 'Applies IDW interpolation at every sampled waypoint to compute average and peak pollution exposure for the commute.')
add_bullet('Quick Delhi Routes', 'Pre-configured rapid comparison presets including Connaught Place to India Gate (3.8 km), Anand Vihar to Connaught Place (14.2 km), and Rohini to Karol Bagh (12.5 km).')
add_bullet('Health vs. Travel Time Trade-Off', 'Displays route duration, traffic congestion indicators, and average AQI exposure, enabling commuters to choose the cleanest path.')
add_dual_images('plan-route.png', 'Interactive Delhi Map & Route Selection Mode', 'route comparision.png', 'Route Exposure Comparison & Clean Travel Advisory')

# 10. Route Telemetry & Prediction Results
add_heading('10. Route Telemetry & Prediction Analysis')
add_para('Detailed route metrics and coordinate predictions are presented to commuters to make informed travel choices:')
add_bullet('Traffic Congestion & Meteorological Ingestion', 'Correlates driving speeds with atmospheric factors along the travel corridor.')
add_bullet('Multi-Pollutant Breakdown', 'Surfaces real-time concentrations for PM2.5, PM10, NO2, SO2, CO, and Ozone with CPCB safety benchmarks.')
add_dual_images('Traffic&whether.png', 'Route Traffic Congestion & Weather Telemetry Snapshot', 'AQI result.png', 'Enriched Spatial AQI Prediction & Pollutant Concentrations')

# 11. Saved History & Health Profile Customization
add_heading('11. Saved History & Health Profile Customization')
add_para('Ensures personalized air quality intelligence and complete search traceability:')
add_bullet('Saved History Screen', 'Tracks recent location checks and route exposure calculations with color-coded circular AQI badges, type indicators, and swipe-to-delete management.')
add_bullet('Health Profile & Sensitivity Calibration', 'Allows users to select demographic profiles (Infant, Child, Adult, Elder) and specify respiratory conditions (e.g. Asthma, dust allergies) to customize exposure warnings.')
add_dual_images('HistoryPage.png', 'Saved History — Recent Delhi Location & Route Checks', 'User Profile.png', 'Health Profile & Demographic Sensitivity Calibration')

# 12. Verification & Repository Stabilization
add_heading('12. Verification & Repository Stabilization')
add_bullet('Live Device Testing', 'Compiled, installed, and validated on the Android Pixel 8 emulator running Android SDK 36, confirming zero runtime crashes, seamless zone switching, and fluid 60fps chart rendering.')
add_bullet('Git Repository Audit', 'Cleaned up 44 redundant duplicate files, obsolete iteration notebooks, and untracked build artifacts, ensuring repository hygiene.')
add_bullet('Version Control Synchronization', 'All production source code, assets, documentation, and configuration files are fully synchronized on GitHub under branch Vaishnavi-R-H.')

# Sign-off
sign_p = doc.add_paragraph()
sign_p.paragraph_format.space_before = Pt(20)
run_s = sign_p.add_run('Submitted by:\nVaishnavi R Honnagudi\nIntern – Springboard AI Program, Infosys')
run_s.font.name = 'Calibri'
run_s.font.size = Pt(11)
run_s.font.bold = True
run_s.font.color.rgb = RGBColor(15, 23, 42)


final_filename = 'Milestone3_Vaishnavi_Final.docx'
doc.save(final_filename)
print(f'Successfully saved: {final_filename}')

try:
    doc.save('Milestone3_Vaishnavi.docx')
    print('Successfully updated: Milestone3_Vaishnavi.docx')
except PermissionError:
    print('Note: Milestone3_Vaishnavi.docx is currently locked/opened in Word. The updated version with all screenshots is saved in Milestone3_Vaishnavi_Final.docx')
except Exception as e:
    print(f'Could not overwrite Milestone3_Vaishnavi.docx: {e}')