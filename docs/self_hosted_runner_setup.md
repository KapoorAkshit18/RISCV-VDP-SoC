# GitHub Actions Self-Hosted Runner Setup Guide (Windows / Git Bash)

This guide walks you through registering your Windows laptop as a **GitHub Actions Self-Hosted Runner** so that GitHub Actions can run **QuestaSim** and **Vivado synthesis** locally on your machine.

---

## 🔒 How It Works & Security
- **No Incoming Ports Needed**: The GitHub Actions runner uses an **outbound HTTPS connection** (port 443) to poll GitHub for queued jobs. You do **not** need a static IP, public IP, or port forwarding on your Wi-Fi/router.
- **Local Tool Access**: Because the runner executes directly on your laptop, it has native access to `C:\Xilinx\Vivado\2020.1` and `C:\questasim64_2024.1\win64`.

---

## Step 1: Open GitHub Runner Settings

1. In your browser, navigate to your repository:
   [https://github.com/KapoorAkshit18/RISCV-VDP-SoC](https://github.com/KapoorAkshit18/RISCV-VDP-SoC)
2. Click **Settings** (top navigation tab).
3. In the left sidebar, expand **Actions** and select **Runners**.
4. Click the green button: **New self-hosted runner**.
5. Select:
   - **Runner image**: `Windows`
   - **Architecture**: `x64`

GitHub will display a token and download instructions.

---

## Step 2: Download and Extract Runner

Open **Git Bash** (or PowerShell/cmd) and create a directory for the runner (e.g. `C:/actions-runner`):

```bash
# Create directory outside your git repo
mkdir -p /c/actions-runner && cd /c/actions-runner

# Download the latest runner package
curl -o actions-runner-win-x64.zip -L https://github.com/actions/runner/releases/download/v2.321.0/actions-runner-win-x64-2.321.0.zip

# Extract using Windows tar
tar -xf actions-runner-win-x64.zip
```

---

## Step 3: Configure the Runner

Run the configuration script with the token provided by GitHub in Step 1:

```bash
# Replace YOUR_TOKEN with the token from your GitHub Runners page
./config.cmd --url https://github.com/KapoorAkshit18/RISCV-VDP-SoC --token YOUR_TOKEN
```

When prompted:
1. **Enter runner group**: Press `Enter` (default).
2. **Enter the name of runner**: e.g., `laptop-envy` (or press `Enter`).
3. **Enter additional labels**: You can press `Enter` (default labels will include `self-hosted` and `windows`).
4. **Enter name of work folder**: Press `Enter` (default `_work`).

---

## Step 4: Start the Runner

### Option A: Run Interactively in Terminal (Recommended for testing)

```bash
./run.cmd
```

You will see:
```text
√ Connected to GitHub
Current runner version: '2.321.0'
Listening for Jobs
```

Whenever you push to `main` or trigger a workflow dispatch, the runner will pick up the jobs, run QuestaSim linting/simulation and Vivado synthesis locally, and report the results back to GitHub!

### Option B: Run as a Background Windows Service (Always-on)

If you want the runner to automatically start on boot in the background:

```bash
./svc.cmd install
./svc.cmd start
```

To stop:
```bash
./svc.cmd stop
./svc.cmd uninstall
```

---

## Step 5: Test Locally Without GitHub

You can also run the exact same CI pipeline locally at any time without waiting for GitHub Actions:

```bash
# In your repo root (in Git Bash):
./run_local_ci.sh all       # Runs QuestaSim Lint + Top Sim + Local Vivado Synthesis
./run_local_ci.sh lint      # Runs QuestaSim Lint only
./run_local_ci.sh sim       # Runs QuestaSim Top Sim only
./run_local_ci.sh synth     # Runs Local Vivado Synthesis only

# Or using Make:
make all
make lint
make sim
make synth
```

