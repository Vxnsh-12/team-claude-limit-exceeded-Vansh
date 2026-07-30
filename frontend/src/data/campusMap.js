// VIT Bhopal (Kotri Kalan) — static campus map data used by MapPage.jsx.
// Coordinates are in SVG units (viewBox 0 0 1500 1000).

export const MAP_VIEWBOX = { w: 1500, h: 1000 };

// Main entry point — every route starts here.
export const MAIN_ENTRY = { x: 810, y: 175 };

export const CATEGORIES = {
  academic:  { label: "Academic / Blocks", color: "#A9C7ED", stroke: "#4B6FA8" },
  residence: { label: "Residence",         color: "#C7B8E8", stroke: "#6E5AA6" },
  food:      { label: "Food / Mess",       color: "#F0B37E", stroke: "#B26A2F" },
  facility:  { label: "Other Facilities",  color: "#F0BEC6", stroke: "#B2606B" },
  sports:    { label: "Open / Sports",     color: "#C7E4A4", stroke: "#5F8A3E" },
};

// Highway + campus road paths (SVG path `d` strings) — drawn as thick grey
// lines with a dashed white centerline overlay for that "printed map" feel.
export const ROADS = [
  // Top highway (curves across)
  { d: "M -20 130 Q 300 60 600 120 T 1000 100 T 1520 60", w: 46 },
  // Off-ramp from highway down to main entry / campus
  { d: "M 900 105 Q 860 145 810 190", w: 34 },
  // Main north-south spine through campus
  { d: "M 810 190 L 810 560", w: 30 },
  // Loop curving south-west toward Porcell / Auditorium
  { d: "M 810 560 Q 700 620 500 700 T 240 780", w: 28 },
  // Loop curving south-east toward hostels & Cricket Ground
  { d: "M 810 560 Q 900 640 1000 680 T 1350 800", w: 28 },
  // Interior connector between the two loops (behind Auditorium)
  { d: "M 500 750 Q 720 830 1000 780", w: 22 },
];

// Trees dotted around green zones / along paths.
export const TREES = [
  [220, 640], [265, 610], [310, 630], [355, 660], [400, 685], [230, 700],
  [265, 730], [305, 760], [345, 785], [385, 810], [220, 760], [260, 795],
  [640, 850], [685, 870], [730, 880], [900, 800], [945, 820], [990, 850],
  [1150, 630], [1195, 615], [1240, 640], [1300, 625], [1355, 645],
  [1140, 900], [1200, 915], [1260, 895], [1330, 905], [1400, 890],
  [130, 830], [180, 850], [95,  760], [140, 780],
];

// Every clickable building. `route` is an ordered list of waypoints from the
// Main Entry to the building's "drop-off" point; used to draw the directions
// polyline.  Each rectangle is defined by `x` (top-left), `y`, `w`, `h`.
export const BUILDINGS = [
  {
    id: "lc", name: "L.C.", full: "Learning Centre", category: "facility",
    x: 730, y: 220, w: 70,  h: 40, labelSize: 15,
    route: [MAIN_ENTRY, { x: 810, y: 240 }, { x: 800, y: 240 }],
  },
  {
    id: "ar", name: "A.R.", full: "Administrative Reception", category: "facility",
    x: 730, y: 290, w: 70,  h: 40, labelSize: 15,
    route: [MAIN_ENTRY, { x: 810, y: 310 }, { x: 800, y: 310 }],
  },
  {
    id: "ab1", name: "A.B. 1", full: "Academic Block 1", category: "academic",
    x: 860, y: 340, w: 160, h: 100, labelSize: 22,
    route: [MAIN_ENTRY, { x: 810, y: 380 }, { x: 860, y: 380 }],
  },
  {
    id: "ub", name: "U.B.", full: "University Block", category: "facility",
    x: 720, y: 400, w: 70,  h: 40, labelSize: 15,
    route: [MAIN_ENTRY, { x: 810, y: 420 }, { x: 790, y: 420 }],
  },
  {
    id: "mayuri", name: "Mayuri (Mess)", full: "Mayuri Central Mess", category: "food",
    x: 715, y: 465, w: 100, h: 55, labelSize: 15,
    route: [MAIN_ENTRY, { x: 810, y: 495 }, { x: 815, y: 495 }],
  },
  {
    id: "chancellor", name: "Chancellor Residence", full: "Chancellor's Residence",
    category: "residence",
    x: 730, y: 625, w: 190, h: 80, labelSize: 15,
    route: [MAIN_ENTRY, { x: 810, y: 560 }, { x: 810, y: 640 }, { x: 830, y: 665 }],
  },
  {
    id: "gb1", name: "Girls Block 1", full: "Girls Hostel · Block 1",
    category: "residence",
    x: 955, y: 620, w: 105, h: 100, labelSize: 15,
    route: [MAIN_ENTRY, { x: 810, y: 560 }, { x: 900, y: 640 }, { x: 1000, y: 670 }],
  },
  {
    id: "gb2", name: "Girls Block 2", full: "Girls Hostel · Block 2",
    category: "residence",
    x: 1095, y: 620, w: 105, h: 100, labelSize: 15,
    route: [MAIN_ENTRY, { x: 810, y: 560 }, { x: 950, y: 660 }, { x: 1140, y: 670 }],
  },
  {
    id: "porcell", name: "Porcell Area", full: "Porcell Ground", category: "sports",
    shape: "blob",
    d: "M 195 615 Q 340 590 470 640 Q 510 700 480 780 Q 350 830 240 810 Q 165 785 175 720 Q 165 660 195 615 Z",
    labelX: 340, labelY: 745, labelSize: 18,
    route: [MAIN_ENTRY, { x: 810, y: 560 }, { x: 550, y: 700 }, { x: 340, y: 745 }],
  },
  {
    id: "audi", name: "Open Auditorium", full: "Open Air Auditorium",
    category: "facility",
    x: 640, y: 780, w: 190, h: 110, labelSize: 16,
    route: [MAIN_ENTRY, { x: 810, y: 560 }, { x: 700, y: 700 }, { x: 735, y: 820 }],
  },
  {
    id: "cricket", name: "Cricket Ground", full: "Cricket Ground · VIT Bhopal",
    category: "sports",
    shape: "rect", rounded: 24,
    x: 1150, y: 640, w: 300, h: 280, labelSize: 20,
    route: [MAIN_ENTRY, { x: 810, y: 560 }, { x: 1000, y: 700 }, { x: 1300, y: 780 }],
    extras: "cricket",
  },
];

// Lookup helper
export const BUILDINGS_BY_ID = Object.fromEntries(BUILDINGS.map((b) => [b.id, b]));
