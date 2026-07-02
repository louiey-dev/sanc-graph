# sanc_graph

graph tool which parses incoming data stream via specific data format and display line chart

## PERSONA

Flutter/Dart SW expert
Graph UI designer
Data parsing expert

## Data stream format

- data format
  - 'data:'
    - '{'
    - "ts":timestamp
    - "seq":3
    - "d":{
      - "cpu0_temp_c":54.75
      - "cpu1_temp_c":49.69
      - "gpu_temp_c":null
      - "soc_temp_c":null
      - "tj_temp_c":null
      - "cpu_load_pct":1.2
      - "core0_load_pct":0.0
      - "core1_load_pct":0.0
      - "core2_load_pct":0.0
      - "core3_load_pct":0.0
      - "core4_load_pct":0.0
      - "core5_load_pct":0.0
      - "core6_load_pct":0.0
      - "core7_load_pct":0.0
      - "gpu_load_pct":null
      - "cpu_clk_mhz":null
      - "gpu_clk_mhz":null
      - "emc_clk_mhz":null
      - "pwr_cpu_mw":null
      - "pwr_gpu_mw":null
      - "pwr_soc_mw":null
      - "pwr_total_mw":null
    - '}'
- Example data sample

  ```bash
  data: {"ts":1782717271072,"seq":7,"d":{"cpu0_temp_c":54.75,"cpu1_temp_c":49.69,"gpu_temp_c":null,"soc_temp_c":null,"tj_temp_c":null,"cpu_load_pct":1.2,"core0_load_pct":0.0,"core1_load_pct":0.0,"core2_load_pct":0.0,"core3_load_pct":0.0,"core4_load_pct":0.0,"core5_load_pct":0.0,"core6_load_pct":0.0,"core7_load_pct":0.0,"gpu_load_pct":null,"cpu_clk_mhz":null,"gpu_clk_mhz":null,"emc_clk_mhz":null,"pwr_cpu_mw":null,"pwr_gpu_mw":null,"pwr_soc_mw":null,"pwr_total_mw":null}}
  ```

## feature

- its data stream send via "http://0.0.0.0:18765/telemetry" from Jetson side
- open url " http://192.168.x.x:18765/telemetry"
- display element "data" at left side with checkbox
- user check checkbox which she wants to display data stream at graph
- user can change the color of the line
- X-axis is "seq"
- user can select Y-Axix 2nd axis by toggle of element
- user can save its stream to csv with ',' seperator
- when mouse hover, it shows the value of data at that point
- windows is resizable
- buttons for start/stop/clear/save data stream
- ip address and port input for http server
- dark/light theme support
