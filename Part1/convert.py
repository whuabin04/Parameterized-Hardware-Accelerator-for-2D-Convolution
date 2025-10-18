import os
import re
import json
import argparse

script_dir = os.path.dirname(os.path.abspath(__file__))
default_file = os.path.join(script_dir, 'synth_mac_output.txt')

def parse_file(path):
    with open(path, 'r') as f:
        text = f.read()

    # ---------- helpers ----------------------------------------------------
    def find_all(pattern, flags=0):
        return re.findall(pattern, text, flags)

    def find_first(pattern, flags=0):
        m = re.search(pattern, text, flags)
        return m.group(1) if m else None
    # -----------------------------------------------------------------------

    result = {}

    # Total cell area
    area = find_first(r"Total cell area:\s*([0-9]*\.?[0-9]+)")
    result['total_cell_area'] = float(area) if area else None

    # Total Dynamic Power (capture number and unit, keep both)
    tdp_match = re.search(r"Total Dynamic Power\s*=\s*([0-9]*\.?[0-9]+(?:[eE][+-]?\d+)?)\s*([A-Za-zμµ]+)", text, re.IGNORECASE)
    result['total_dynamic_power'] = f"{tdp_match.group(1)} {tdp_match.group(2)}" if tdp_match else None

    # Cell Leakage Power (capture number and unit, keep both)
    leak_match = re.search(r"Cell Leakage Power\s*=\s*([0-9]*\.?[0-9]+(?:[eE][+-]?\d+)?)\s*([A-Za-zμµ]+)", text, re.IGNORECASE)
    result['cell_leakage_power'] = f"{leak_match.group(1)} {leak_match.group(2)}" if leak_match else None

    # slack (MET) – last occurrence
    slack_matches = find_all(r"slack \(MET\)\s*([+-]?[0-9]*\.?[0-9]+)")
    if slack_matches:
        result['slack'] = float(slack_matches[-1])
    else:                                   # fallback
        slack_loose = find_first(r"slack\s+([+-]?[0-9]*\.?[0-9]+)")
        result['slack_MET'] = float(slack_loose) if slack_loose else None

    # data arrival time – first occurrence (changed to first)
    data_arrivals = find_all(r"data arrival time\s*([+-]?[0-9]*\.?[0-9]+)")
    result['data_arrival_time'] = float(data_arrivals[0]) if data_arrivals else None

    # ------------------------------------------------------------------
    #  Startpoint / Endpoint – tolerate multi-line descriptions
    # ------------------------------------------------------------------
    #   (?si)  ->  case-insensitive, dot matches newline
    #   .*?    ->  non-greedy scan until the first blank line or next keyword
    # ------------------------------------------------------------------
    startblock = find_first(r"(?si)Startpoint:\s*(.*?)(?:\n\s*\n|^\s*$|^\s*\w+[^:]*:\s*)")
    if startblock:
        # remove any "Path Group:" or "Path Type:" lines from the captured block
        startblock_clean = re.sub(r"(?im)^\s*(Path\s+Group:.*|Path\s+Type:.*)\s*$", "", startblock)
        # collapse whitespace and store, include "Startpoint:" prefix
        cleaned = " ".join(startblock_clean.split())
        result['start/end'] = "Startpoint: " + cleaned if cleaned else None
    else:
        result['start/end'] = None

    return result


def main():
    parser = argparse.ArgumentParser(description='Parse synth output for key metrics')
    parser.add_argument('-f', '--file', default=default_file, help='Path to synth output file')
    parser.add_argument('-j', '--json', action='store_true', help='Print JSON')
    args = parser.parse_args()

    if not os.path.isfile(args.file):
        print(f"File not found: {args.file}")
        return

    data = parse_file(args.file)

    if args.json:
        print(json.dumps(data, indent=2))
    else:
        print('Parsed results:')
        for k, v in data.items():
            print(f"{k}: {v}")


if __name__ == '__main__':
    main()