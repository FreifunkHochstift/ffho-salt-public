mine_functions:
  minion_id:
    - mine_function: grains.get
    - id
    - mine_interval: 10

schedule:
  daily_high_state:
    function: state.highstate
    when: 6:00am
