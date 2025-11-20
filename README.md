# Automated System Health Monitor (ASHM)

## 🎯 Project Overview & Goal

The Automated System Health Monitor (ASHM) is a comprehensive, multi-component diagnostic and resource management utility. Its primary objective is to transform complex, real-time operating system metrics into clear, actionable data for continuous operational awareness and predictive maintenance.

The project demonstrates advanced competencies in system automation, cross-platform scripting, data presentation, and proactive alerting mechanisms.

## ✨ Core Functionality & Technical Scope

**ASHM is defined by three core functional pillars:**

### 1. Instant Health Check & Visual Reporting

- **Data Collection:** Gathers low-level, in-depth data on all critical components, including hardware specifications, resource utilization (CPU, Memory, Storage), network configuration, running processes, and patch status.
- **Visual Output:** Generates a single, modern, and intuitive HTML dashboard report file. The report uses clear sectional organization and graphical elements to instantly highlight system status.

### 2. Monitoring and Limit Logic

- **Threshold Management:** Implements safety checks against customizable resource consumption thresholds (e.g., CPU > 90%, RAM > 95%).
- **Status Assessment:** Calculates an overall System Health Status (Green, Yellow, Red) based on real-time metrics, providing instant health feedback on the report dashboard.
- **Scheduling Integration:** Designed for background execution using the host system's native scheduling service (e.g., cron or Task Scheduler) for constant, automated surveillance.

### 3. Automated Alerting

- **Instant Notification:** Upon the breach of any predefined critical threshold, the system triggers an immediate warning.
- **Messaging Integration:** Utilizes standard messaging protocols (e.g., email) to send urgent alerts containing specific diagnostic details about the broken limit.
