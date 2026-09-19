// Generated from the supplied Lua configuration for local UI development.
// Replace this mock source with NUI messages when game integration begins.
import type { BusinessLocation, BusinessTier } from '@/types/business'

export const businessTiers: BusinessTier[] = [
  {
    "tier": 1,
    "type": "coffee_shop",
    "label": "Coffee Shop",
    "weight": 1,
    "requiredPoints": 0,
    "price": 15000,
    "npc": "s_m_y_waiter_01",
    "expectedRevenue": 3000,
    "launderFee": 25
  },
  {
    "tier": 2,
    "type": "gas_station",
    "label": "Gas Station",
    "weight": 1,
    "requiredPoints": 500,
    "price": 25000,
    "npc": "s_m_y_xmech_02",
    "expectedRevenue": 6000,
    "launderFee": 23
  },
  {
    "tier": 3,
    "type": "restaurant",
    "label": "Restaurant",
    "weight": 2,
    "requiredPoints": 1500,
    "price": 40000,
    "npc": "s_m_y_chef_01",
    "expectedRevenue": 10000,
    "launderFee": 22
  },
  {
    "tier": 4,
    "type": "laundromat",
    "label": "Laundromat",
    "weight": 2,
    "requiredPoints": 2750,
    "price": 55000,
    "npc": "s_m_o_busker_01",
    "expectedRevenue": 15000,
    "launderFee": 21
  },
  {
    "tier": 5,
    "type": "bar",
    "label": "Bar",
    "weight": 3,
    "requiredPoints": 4000,
    "price": 75000,
    "npc": "s_m_y_barman_01",
    "expectedRevenue": 22000,
    "launderFee": 20
  },
  {
    "tier": 6,
    "type": "nightclub",
    "label": "Nightclub",
    "weight": 3,
    "requiredPoints": 5500,
    "price": 100000,
    "npc": "s_m_y_clubbar_01",
    "expectedRevenue": 32000,
    "launderFee": 19
  },
  {
    "tier": 7,
    "type": "stripclub",
    "label": "Strip Club",
    "weight": 3,
    "requiredPoints": 7500,
    "price": 150000,
    "npc": "s_m_y_doorman_01",
    "expectedRevenue": 45000,
    "launderFee": 18
  },
  {
    "tier": 8,
    "type": "carwash",
    "label": "Car Wash",
    "weight": 5,
    "requiredPoints": 10000,
    "price": 250000,
    "npc": "s_m_y_winclean_01",
    "expectedRevenue": 65000,
    "launderFee": 17
  },
  {
    "tier": 9,
    "type": "casino",
    "label": "Casino",
    "weight": 6,
    "requiredPoints": 15000,
    "price": 750000,
    "npc": "s_m_y_casino_01",
    "expectedRevenue": 100000,
    "launderFee": 15
  }
]

export const businessLocations: BusinessLocation[] = [
  {
    "uid": "coffee_shop:1",
    "id": 1,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -836.874695,
      "y": -609.50769,
      "z": 29.010254,
      "heading": 144.56691
    }
  },
  {
    "uid": "coffee_shop:2",
    "id": 2,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -1368.092285,
      "y": -207.679123,
      "z": 44.512085,
      "heading": 147.401581
    }
  },
  {
    "uid": "coffee_shop:3",
    "id": 3,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -689.208801,
      "y": -854.716492,
      "z": 23.820557,
      "heading": 0
    }
  },
  {
    "uid": "coffee_shop:4",
    "id": 4,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": 282.659332,
      "y": -963.784607,
      "z": 29.414673,
      "heading": 357.165344
    }
  },
  {
    "uid": "coffee_shop:5",
    "id": 5,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -1706.202148,
      "y": -1100.083496,
      "z": 13.137695,
      "heading": 320.314972
    }
  },
  {
    "uid": "coffee_shop:6",
    "id": 6,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -602.017578,
      "y": -1107.112061,
      "z": 22.320923,
      "heading": 269.291351
    }
  },
  {
    "uid": "coffee_shop:7",
    "id": 7,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -312.237366,
      "y": -823.542847,
      "z": 32.41394,
      "heading": 107.716537
    }
  },
  {
    "uid": "coffee_shop:8",
    "id": 8,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -844.19342,
      "y": -349.503296,
      "z": 38.665161,
      "heading": 249.448822
    }
  },
  {
    "uid": "coffee_shop:9",
    "id": 9,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -629.182434,
      "y": 238.298904,
      "z": 81.88501,
      "heading": 8.503937
    }
  },
  {
    "uid": "coffee_shop:10",
    "id": 10,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -691.80658,
      "y": 314.887909,
      "z": 83.098145,
      "heading": 192.75592
    }
  },
  {
    "uid": "coffee_shop:11",
    "id": 11,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -1283.74939,
      "y": -1130.703247,
      "z": 6.7854,
      "heading": 136.062988
    }
  },
  {
    "uid": "coffee_shop:12",
    "id": 12,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": 126.342857,
      "y": -1028.162598,
      "z": 29.34729,
      "heading": 348.661407
    }
  },
  {
    "uid": "coffee_shop:13",
    "id": 13,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -660.738464,
      "y": -815.630737,
      "z": 24.528198,
      "heading": 235.275589
    }
  },
  {
    "uid": "coffee_shop:14",
    "id": 14,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -271.279114,
      "y": -977.010986,
      "z": 31.200684,
      "heading": 181.417328
    }
  },
  {
    "uid": "coffee_shop:15",
    "id": 15,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -1345.265991,
      "y": -610.021973,
      "z": 28.605835,
      "heading": 291.968506
    }
  },
  {
    "uid": "coffee_shop:16",
    "id": 16,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": -1548.237305,
      "y": -434.610992,
      "z": 35.88501,
      "heading": 240.944885
    }
  },
  {
    "uid": "coffee_shop:17",
    "id": 17,
    "type": "coffee_shop",
    "brand": "Cool Beans",
    "coords": {
      "x": -1280.610962,
      "y": -875.261536,
      "z": 11.924561,
      "heading": 138.897629
    }
  },
  {
    "uid": "coffee_shop:18",
    "id": 18,
    "type": "coffee_shop",
    "brand": "Cool Beans",
    "coords": {
      "x": 1177.318726,
      "y": -405.560425,
      "z": 67.764893,
      "heading": 266.456696
    }
  },
  {
    "uid": "coffee_shop:19",
    "id": 19,
    "type": "coffee_shop",
    "brand": "Cool Beans",
    "coords": {
      "x": 265.292297,
      "y": -981.731873,
      "z": 29.34729,
      "heading": 70.866142
    }
  },
  {
    "uid": "coffee_shop:20",
    "id": 20,
    "type": "coffee_shop",
    "brand": "Cool Beans",
    "coords": {
      "x": -1206.210938,
      "y": -1136.043945,
      "z": 7.678345,
      "heading": 110.551186
    }
  },
  {
    "uid": "coffee_shop:21",
    "id": 21,
    "type": "coffee_shop",
    "brand": "Bean Machine",
    "coords": {
      "x": 462.843964,
      "y": -718.15387,
      "z": 27.51062,
      "heading": 85.039368
    }
  },
  {
    "uid": "gas_station:1",
    "id": 1,
    "type": "gas_station",
    "brand": "RON",
    "coords": {
      "x": 817.054932,
      "y": -1040.782471,
      "z": 26.735474,
      "heading": 0
    }
  },
  {
    "uid": "gas_station:2",
    "id": 2,
    "type": "gas_station",
    "brand": "RON",
    "coords": {
      "x": 163.476929,
      "y": -1556.980225,
      "z": 29.246094,
      "heading": 229.606293
    }
  },
  {
    "uid": "gas_station:3",
    "id": 3,
    "type": "gas_station",
    "brand": "RON",
    "coords": {
      "x": 181.859344,
      "y": 6637.028809,
      "z": 31.621948,
      "heading": 175.748032
    },
    "price": 20000
  },
  {
    "uid": "gas_station:4",
    "id": 4,
    "type": "gas_station",
    "brand": "RON",
    "coords": {
      "x": 1213.331909,
      "y": -1389.07251,
      "z": 35.362671,
      "heading": 184.251968
    }
  },
  {
    "uid": "gas_station:5",
    "id": 5,
    "type": "gas_station",
    "brand": "RON",
    "coords": {
      "x": -1427.498901,
      "y": -269.221985,
      "z": 46.213867,
      "heading": 121.889763
    }
  },
  {
    "uid": "gas_station:6",
    "id": 6,
    "type": "gas_station",
    "brand": "RON",
    "coords": {
      "x": -2546.123047,
      "y": 2315.85498,
      "z": 33.205811,
      "heading": 5.669291
    },
    "price": 20000
  },
  {
    "uid": "gas_station:7",
    "id": 7,
    "type": "gas_station",
    "brand": "RON",
    "coords": {
      "x": 2558.887939,
      "y": 358.931885,
      "z": 108.608765,
      "heading": 272.125977
    }
  },
  {
    "uid": "gas_station:8",
    "id": 8,
    "type": "gas_station",
    "brand": "Xero Gas",
    "coords": {
      "x": 288.883514,
      "y": -1265.182373,
      "z": 29.431519,
      "heading": 85.039368
    }
  },
  {
    "uid": "gas_station:9",
    "id": 9,
    "type": "gas_station",
    "brand": "Xero Gas",
    "coords": {
      "x": -2073.217529,
      "y": -326.769226,
      "z": 13.306274,
      "heading": 85.039368
    }
  },
  {
    "uid": "gas_station:10",
    "id": 10,
    "type": "gas_station",
    "brand": "Xero Gas",
    "coords": {
      "x": 47.538464,
      "y": 2788.127441,
      "z": 57.874023,
      "heading": 147.401581
    },
    "price": 20000
  },
  {
    "uid": "gas_station:11",
    "id": 11,
    "type": "gas_station",
    "brand": "Xero Gas",
    "coords": {
      "x": -530.769226,
      "y": -1221.547241,
      "z": 18.445435,
      "heading": 337.322845
    }
  },
  {
    "uid": "gas_station:12",
    "id": 12,
    "type": "gas_station",
    "brand": "Xero Gas",
    "coords": {
      "x": -92.162636,
      "y": 6411.046387,
      "z": 31.638794,
      "heading": 36.850395
    },
    "price": 20000
  },
  {
    "uid": "gas_station:13",
    "id": 13,
    "type": "gas_station",
    "brand": "Xero Gas",
    "coords": {
      "x": 2673.138428,
      "y": 3265.410889,
      "z": 55.228516,
      "heading": 246.614166
    },
    "price": 20000
  },
  {
    "uid": "gas_station:14",
    "id": 14,
    "type": "gas_station",
    "brand": "Globe Oil",
    "coords": {
      "x": 1699.450562,
      "y": 6425.48584,
      "z": 32.750977,
      "heading": 150.236221
    },
    "price": 20000
  },
  {
    "uid": "gas_station:15",
    "id": 15,
    "type": "gas_station",
    "brand": "Globe Oil",
    "coords": {
      "x": -342.316467,
      "y": -1476.39563,
      "z": 30.745728,
      "heading": 277.795288
    }
  },
  {
    "uid": "gas_station:16",
    "id": 16,
    "type": "gas_station",
    "brand": "Globe Oil",
    "coords": {
      "x": 642.197815,
      "y": 260.373627,
      "z": 103.284302,
      "heading": 59.527554
    }
  },
  {
    "uid": "gas_station:17",
    "id": 17,
    "type": "gas_station",
    "brand": "Globe Oil",
    "coords": {
      "x": 1778.109863,
      "y": 3325.780273,
      "z": 41.428589,
      "heading": 300.472443
    },
    "price": 20000
  },
  {
    "uid": "gas_station:18",
    "id": 18,
    "type": "gas_station",
    "brand": "Globe Oil",
    "coords": {
      "x": 265.846161,
      "y": 2598.224121,
      "z": 44.832275,
      "heading": 8.503937
    },
    "price": 20000
  },
  {
    "uid": "gas_station:19",
    "id": 19,
    "type": "gas_station",
    "brand": "Globe Oil",
    "coords": {
      "x": 1039.37146,
      "y": 2664.18457,
      "z": 39.541382,
      "heading": 0
    },
    "price": 20000
  },
  {
    "uid": "gas_station:20",
    "id": 20,
    "type": "gas_station",
    "brand": "LTD Gasoline",
    "coords": {
      "x": -1819.621948,
      "y": 797.380249,
      "z": 138.129639,
      "heading": 300.472443
    }
  },
  {
    "uid": "gas_station:21",
    "id": 21,
    "type": "gas_station",
    "brand": "LTD Gasoline",
    "coords": {
      "x": 1167.296753,
      "y": -323.802185,
      "z": 69.247559,
      "heading": 283.464569
    }
  },
  {
    "uid": "gas_station:22",
    "id": 22,
    "type": "gas_station",
    "brand": "LTD Gasoline",
    "coords": {
      "x": -703.424194,
      "y": -935.367004,
      "z": 19.203613,
      "heading": 93.543304
    }
  },
  {
    "uid": "gas_station:23",
    "id": 23,
    "type": "gas_station",
    "brand": "LTD Gasoline",
    "coords": {
      "x": -52.430771,
      "y": -1770.606567,
      "z": 29.161865,
      "heading": 48.188972
    }
  },
  {
    "uid": "gas_station:24",
    "id": 24,
    "type": "gas_station",
    "brand": "LTD Gasoline",
    "coords": {
      "x": 1694.795654,
      "y": 4924.035156,
      "z": 42.220459,
      "heading": 53.858269
    },
    "price": 20000
  },
  {
    "uid": "restaurant:1",
    "id": 1,
    "type": "restaurant",
    "brand": "Pizza This",
    "coords": {
      "x": 537.059326,
      "y": 102.224182,
      "z": 96.561157,
      "heading": 164.409454
    }
  },
  {
    "uid": "restaurant:2",
    "id": 2,
    "type": "restaurant",
    "brand": "Pizza This",
    "coords": {
      "x": -1529.353882,
      "y": -908.808777,
      "z": 10.155273,
      "heading": 133.228333
    }
  },
  {
    "uid": "restaurant:3",
    "id": 3,
    "type": "restaurant",
    "brand": "Pizza This",
    "coords": {
      "x": 288.712097,
      "y": -963.982422,
      "z": 29.414673,
      "heading": 5.669291
    }
  },
  {
    "uid": "restaurant:4",
    "id": 4,
    "type": "restaurant",
    "brand": "Pizza This",
    "coords": {
      "x": 482.940674,
      "y": 71.920883,
      "z": 96.409546,
      "heading": 314.64566
    }
  },
  {
    "uid": "restaurant:5",
    "id": 5,
    "type": "restaurant",
    "brand": "Pizza This",
    "coords": {
      "x": 222.804398,
      "y": -19.991207,
      "z": 74.976562,
      "heading": 181.417328
    }
  },
  {
    "uid": "restaurant:6",
    "id": 6,
    "type": "restaurant",
    "brand": "Cluckin' Bell",
    "coords": {
      "x": -1682.558228,
      "y": -1096.747192,
      "z": 13.137695,
      "heading": 184.251968
    }
  },
  {
    "uid": "restaurant:7",
    "id": 7,
    "type": "restaurant",
    "brand": "Cluckin' Bell",
    "coords": {
      "x": -139.358246,
      "y": -255.771423,
      "z": 43.585327,
      "heading": 297.637787
    }
  },
  {
    "uid": "restaurant:8",
    "id": 8,
    "type": "restaurant",
    "brand": "Cluckin' Bell",
    "coords": {
      "x": -181.015381,
      "y": -1429.041748,
      "z": 31.30188,
      "heading": 294.803162
    }
  },
  {
    "uid": "restaurant:9",
    "id": 9,
    "type": "restaurant",
    "brand": "Burger Shot",
    "coords": {
      "x": -1689.270264,
      "y": -1090.285767,
      "z": 13.137695,
      "heading": 141.732285
    }
  },
  {
    "uid": "restaurant:10",
    "id": 10,
    "type": "restaurant",
    "brand": "Burger Shot",
    "coords": {
      "x": -1178.175781,
      "y": -891.837341,
      "z": 13.744385,
      "heading": 311.811035
    }
  },
  {
    "uid": "restaurant:11",
    "id": 11,
    "type": "restaurant",
    "brand": "Taco Bomb",
    "coords": {
      "x": -1553.617554,
      "y": -440.980225,
      "z": 40.518677,
      "heading": 229.606293
    }
  },
  {
    "uid": "restaurant:12",
    "id": 12,
    "type": "restaurant",
    "brand": "Taco Bomb",
    "coords": {
      "x": -658.852722,
      "y": -676.707703,
      "z": 31.520874,
      "heading": 317.480316
    }
  },
  {
    "uid": "restaurant:13",
    "id": 13,
    "type": "restaurant",
    "brand": "Taco Bomb",
    "coords": {
      "x": -1198.391235,
      "y": -789.995605,
      "z": 16.406616,
      "heading": 130.393707
    }
  },
  {
    "uid": "restaurant:14",
    "id": 14,
    "type": "restaurant",
    "brand": "Wigwam Burger",
    "coords": {
      "x": -1533.138428,
      "y": -454.496704,
      "z": 35.88501,
      "heading": 328.818909
    }
  },
  {
    "uid": "restaurant:15",
    "id": 15,
    "type": "restaurant",
    "brand": "Wigwam Burger",
    "coords": {
      "x": -857.340637,
      "y": -1140.158203,
      "z": 6.970703,
      "heading": 204.094498
    }
  },
  {
    "uid": "restaurant:16",
    "id": 16,
    "type": "restaurant",
    "brand": "Up-n-Atom Burger",
    "coords": {
      "x": -1544.109863,
      "y": -468.237366,
      "z": 35.463745,
      "heading": 172.913391
    }
  },
  {
    "uid": "restaurant:17",
    "id": 17,
    "type": "restaurant",
    "brand": "Up-n-Atom Burger",
    "coords": {
      "x": 79.885712,
      "y": 275.261536,
      "z": 110.209473,
      "heading": 198.425201
    }
  },
  {
    "uid": "restaurant:18",
    "id": 18,
    "type": "restaurant",
    "brand": "Up-n-Atom Burger",
    "coords": {
      "x": 1588.971436,
      "y": 6449.907715,
      "z": 25.303345,
      "heading": 153.070862
    },
    "price": 35000
  },
  {
    "uid": "restaurant:19",
    "id": 19,
    "type": "restaurant",
    "brand": "Lucky Plucker",
    "coords": {
      "x": -587.406616,
      "y": -872.13623,
      "z": 25.842529,
      "heading": 354.330719
    }
  },
  {
    "uid": "restaurant:20",
    "id": 20,
    "type": "restaurant",
    "brand": "Lucky Plucker",
    "coords": {
      "x": 131.736267,
      "y": -1464.079102,
      "z": 29.34729,
      "heading": 56.692913
    }
  },
  {
    "uid": "restaurant:21",
    "id": 21,
    "type": "restaurant",
    "brand": "Bishop's Chicken",
    "coords": {
      "x": 167.723083,
      "y": -1635.059326,
      "z": 29.279907,
      "heading": 36.850395
    }
  },
  {
    "uid": "restaurant:22",
    "id": 22,
    "type": "restaurant",
    "brand": "Bishop's Chicken",
    "coords": {
      "x": 2579.103271,
      "y": 464.861542,
      "z": 108.62561,
      "heading": 178.582672
    }
  },
  {
    "uid": "laundromat:1",
    "id": 1,
    "type": "laundromat",
    "brand": "Suds Law Laundromat",
    "coords": {
      "x": 85.213188,
      "y": -1549.833008,
      "z": 29.58313,
      "heading": 45.354328
    }
  },
  {
    "uid": "laundromat:2",
    "id": 2,
    "type": "laundromat",
    "brand": "Panache Laundering",
    "coords": {
      "x": -1412.373657,
      "y": -383.010986,
      "z": 36.76123,
      "heading": 308.976379
    }
  },
  {
    "uid": "laundromat:3",
    "id": 3,
    "type": "laundromat",
    "brand": "Panache Laundering",
    "coords": {
      "x": 509.802185,
      "y": -1459.424194,
      "z": 29.448364,
      "heading": 337.322845
    }
  },
  {
    "uid": "laundromat:4",
    "id": 4,
    "type": "laundromat",
    "brand": "Coin-Op Laundry",
    "coords": {
      "x": 218.63736,
      "y": -19.885712,
      "z": 69.887939,
      "heading": 161.574799
    }
  },
  {
    "uid": "laundromat:5",
    "id": 5,
    "type": "laundromat",
    "brand": "Go And Wash",
    "coords": {
      "x": 169.661545,
      "y": -1507.424194,
      "z": 29.246094,
      "heading": 133.228333
    }
  },
  {
    "uid": "laundromat:6",
    "id": 6,
    "type": "laundromat",
    "brand": "Sheet Yourself Laundromat",
    "coords": {
      "x": 216.0923,
      "y": -1523.881348,
      "z": 29.279907,
      "heading": 274.960632
    }
  },
  {
    "uid": "laundromat:7",
    "id": 7,
    "type": "laundromat",
    "brand": "Avalon Laundry & Dry Cleaners",
    "coords": {
      "x": 436.153839,
      "y": -2087.156006,
      "z": 21.697388,
      "heading": 223.937012
    }
  },
  {
    "uid": "laundromat:8",
    "id": 8,
    "type": "laundromat",
    "brand": "No Marks Cleaners",
    "coords": {
      "x": -52.21978,
      "y": 6458.874512,
      "z": 31.487183,
      "heading": 48.188972
    },
    "price": 45000
  },
  {
    "uid": "laundromat:9",
    "id": 9,
    "type": "laundromat",
    "brand": "No Marks Cleaners",
    "coords": {
      "x": -3053.973633,
      "y": 635.986816,
      "z": 7.391968,
      "heading": 291.968506
    },
    "price": 45000
  },
  {
    "uid": "bar:1",
    "id": 1,
    "type": "bar",
    "brand": "Hi-Men",
    "coords": {
      "x": 495.61319,
      "y": -1540.536255,
      "z": 29.279907,
      "heading": 235.275589
    }
  },
  {
    "uid": "bar:2",
    "id": 2,
    "type": "bar",
    "brand": "Shenanigan's Bar",
    "coords": {
      "x": 255.309891,
      "y": -1012.325256,
      "z": 29.263062,
      "heading": 70.866142
    }
  },
  {
    "uid": "bar:3",
    "id": 3,
    "type": "bar",
    "brand": "Singleton's",
    "coords": {
      "x": 218.795609,
      "y": 302.729675,
      "z": 105.575806,
      "heading": 263.62207
    }
  },
  {
    "uid": "bar:4",
    "id": 4,
    "type": "bar",
    "brand": "Yellow Jack Inn",
    "coords": {
      "x": 1986.276978,
      "y": 3055.529785,
      "z": 47.208008,
      "heading": 221.102371
    },
    "price": 60000
  },
  {
    "uid": "bar:5",
    "id": 5,
    "type": "bar",
    "brand": "The Bay Bar",
    "coords": {
      "x": -262.153839,
      "y": 6291.428711,
      "z": 31.487183,
      "heading": 226.771667
    },
    "price": 60000
  },
  {
    "uid": "bar:6",
    "id": 6,
    "type": "bar",
    "brand": "Mojito Inn",
    "coords": {
      "x": -131.248352,
      "y": 6378.632812,
      "z": 32.177979,
      "heading": 127.559052
    },
    "price": 60000
  },
  {
    "uid": "bar:7",
    "id": 7,
    "type": "bar",
    "brand": "Tequi-la-la",
    "coords": {
      "x": -554.808777,
      "y": 273.810974,
      "z": 82.99707,
      "heading": 147.401581
    }
  },
  {
    "uid": "bar:8",
    "id": 8,
    "type": "bar",
    "brand": "Mirror Park Tavern",
    "coords": {
      "x": 1217.591187,
      "y": -417.969238,
      "z": 67.764893,
      "heading": 42.519684
    }
  },
  {
    "uid": "nightclub:1",
    "id": 1,
    "type": "nightclub",
    "brand": "Bahama Mamas",
    "coords": {
      "x": -1390.773682,
      "y": -588.092285,
      "z": 30.223389,
      "heading": 28.346457
    }
  },
  {
    "uid": "nightclub:2",
    "id": 2,
    "type": "nightclub",
    "brand": "Cockatoos",
    "coords": {
      "x": -430.681305,
      "y": -23.406591,
      "z": 46.213867,
      "heading": 252.283463
    }
  },
  {
    "uid": "nightclub:3",
    "id": 3,
    "type": "nightclub",
    "brand": "The Lust Resort",
    "coords": {
      "x": -575.050537,
      "y": 239.221985,
      "z": 82.67688,
      "heading": 0
    }
  },
  {
    "uid": "nightclub:4",
    "id": 4,
    "type": "nightclub",
    "brand": "Society",
    "coords": {
      "x": -741.797791,
      "y": 247.292313,
      "z": 77.318726,
      "heading": 184.251968
    }
  },
  {
    "uid": "nightclub:5",
    "id": 5,
    "type": "nightclub",
    "brand": "The Vault",
    "coords": {
      "x": 232.246155,
      "y": -1096.338501,
      "z": 29.279907,
      "heading": 85.039368
    }
  },
  {
    "uid": "stripclub:1",
    "id": 1,
    "type": "stripclub",
    "brand": "Vanilla Unicorn",
    "coords": {
      "x": 93.112091,
      "y": -1292.268188,
      "z": 29.263062,
      "heading": 300.472443
    }
  },
  {
    "uid": "stripclub:2",
    "id": 2,
    "type": "stripclub",
    "brand": "Hornbills",
    "coords": {
      "x": -378.553833,
      "y": 218.63736,
      "z": 83.654175,
      "heading": 2.834646
    }
  },
  {
    "uid": "stripclub:3",
    "id": 3,
    "type": "stripclub",
    "brand": "Pitchers",
    "coords": {
      "x": 225.810989,
      "y": 337.041748,
      "z": 105.592651,
      "heading": 5.669291
    }
  },
  {
    "uid": "stripclub:4",
    "id": 4,
    "type": "stripclub",
    "brand": "The Hen House",
    "coords": {
      "x": -301.767029,
      "y": 6254.637207,
      "z": 31.504028,
      "heading": 229.606293
    },
    "price": 120000
  },
  {
    "uid": "carwash:1",
    "id": 1,
    "type": "carwash",
    "brand": "Hands On Car Wash",
    "coords": {
      "x": -2.71648,
      "y": -1396.892334,
      "z": 29.246094,
      "heading": 90.708656
    }
  },
  {
    "uid": "carwash:2",
    "id": 2,
    "type": "carwash",
    "brand": "Ronnie's Luxury Car Wash",
    "coords": {
      "x": 162.05275,
      "y": -1717.463745,
      "z": 29.279907,
      "heading": 209.763779
    }
  },
  {
    "uid": "casino:1",
    "id": 1,
    "type": "casino",
    "brand": "The Diamond Casino",
    "coords": {
      "x": 931.186829,
      "y": 35.920883,
      "z": 81.093018,
      "heading": 11.338582
    }
  }
]
