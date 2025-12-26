Config parse
    Parse [section] where section can be default, host, user@host, host:suffix, user@host:suffix
    For each key=value, store in cfg_<suffix>_<key>_
    Mark job if suffix != "default" and section != "default"
    Provide a get function that checks suffix, then default, then built-ins
    Collect all job suffixes and sort them
