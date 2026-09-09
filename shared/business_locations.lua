-- All 95 real GTA V business locations indexed by [type][id]
-- id is an explicit table key (not array position) so locations can be
-- reordered or removed without breaking existing ownership records in the DB
-- Optional per-location `price` field overrides the tier base price
-- (useful for rural/less desirable spots e.g. Paleto Bay, Sandy Shores)

return {
    -- TIER 1: Coffee Shop (21 locations)
    coffee_shop = {
        [1]  = {coords = vector4(-836.874695, -609.507690, 29.010254, 144.566910),   brand = "Bean Machine"},
        [2]  = {coords = vector4(-1368.092285, -207.679123, 44.512085, 147.401581),  brand = "Bean Machine"},
        [3]  = {coords = vector4(-689.208801, -854.716492, 23.820557, 0.000000),     brand = "Bean Machine"},
        [4]  = {coords = vector4(282.659332, -963.784607, 29.414673, 357.165344),    brand = "Bean Machine"},
        [5]  = {coords = vector4(-1706.202148, -1100.083496, 13.137695, 320.314972), brand = "Bean Machine"},
        [6]  = {coords = vector4(-602.017578, -1107.112061, 22.320923, 269.291351),  brand = "Bean Machine"},
        [7]  = {coords = vector4(-312.237366, -823.542847, 32.413940, 107.716537),   brand = "Bean Machine"},
        [8]  = {coords = vector4(-844.193420, -349.503296, 38.665161, 249.448822),   brand = "Bean Machine"},
        [9]  = {coords = vector4(-629.182434, 238.298904, 81.885010, 8.503937),      brand = "Bean Machine"},
        [10] = {coords = vector4(-691.806580, 314.887909, 83.098145, 192.755920),    brand = "Bean Machine"},
        [11] = {coords = vector4(-1283.749390, -1130.703247, 6.785400, 136.062988),  brand = "Bean Machine"},
        [12] = {coords = vector4(126.342857, -1028.162598, 29.347290, 348.661407),   brand = "Bean Machine"},
        [13] = {coords = vector4(-660.738464, -815.630737, 24.528198, 235.275589),   brand = "Bean Machine"},
        [14] = {coords = vector4(-271.279114, -977.010986, 31.200684, 181.417328),   brand = "Bean Machine"},
        [15] = {coords = vector4(-1345.265991, -610.021973, 28.605835, 291.968506),  brand = "Bean Machine"},
        [16] = {coords = vector4(-1548.237305, -434.610992, 35.885010, 240.944885),  brand = "Bean Machine"},
        [17] = {coords = vector4(-1280.610962, -875.261536, 11.924561, 138.897629),  brand = "Cool Beans"},
        [18] = {coords = vector4(1177.318726, -405.560425, 67.764893, 266.456696),   brand = "Cool Beans"},
        [19] = {coords = vector4(265.292297, -981.731873, 29.347290, 70.866142),     brand = "Cool Beans"},
        [20] = {coords = vector4(-1206.210938, -1136.043945, 7.678345, 110.551186),  brand = "Cool Beans"},
        [21] = {coords = vector4(462.843964, -718.153870, 27.510620, 85.039368),     brand = "Bean Machine"},
    },

    -- TIER 2: Gas Station (24 locations)
    gas_station = {
        [1]  = {coords = vector4(817.054932, -1040.782471, 26.735474, 0.000000),      brand = "RON"},
        [2]  = {coords = vector4(163.476929, -1556.980225, 29.246094, 229.606293),    brand = "RON"},
        [3]  = {coords = vector4(181.859344, 6637.028809, 31.621948, 175.748032),     brand = "RON",        price = 20000},
        [4]  = {coords = vector4(1213.331909, -1389.072510, 35.362671, 184.251968),   brand = "RON"},
        [5]  = {coords = vector4(-1427.498901, -269.221985, 46.213867, 121.889763),   brand = "RON"},
        [6]  = {coords = vector4(-2546.123047, 2315.854980, 33.205811, 5.669291),     brand = "RON",        price = 20000},
        [7]  = {coords = vector4(2558.887939, 358.931885, 108.608765, 272.125977),    brand = "RON"},
        [8]  = {coords = vector4(288.883514, -1265.182373, 29.431519, 85.039368),     brand = "Xero Gas"},
        [9]  = {coords = vector4(-2073.217529, -326.769226, 13.306274, 85.039368),    brand = "Xero Gas"},
        [10] = {coords = vector4(47.538464, 2788.127441, 57.874023, 147.401581),      brand = "Xero Gas",   price = 20000},
        [11] = {coords = vector4(-530.769226, -1221.547241, 18.445435, 337.322845),   brand = "Xero Gas"},
        [12] = {coords = vector4(-92.162636, 6411.046387, 31.638794, 36.850395),      brand = "Xero Gas",   price = 20000},
        [13] = {coords = vector4(2673.138428, 3265.410889, 55.228516, 246.614166),    brand = "Xero Gas",   price = 20000},
        [14] = {coords = vector4(1699.450562, 6425.485840, 32.750977, 150.236221),    brand = "Globe Oil",  price = 20000},
        [15] = {coords = vector4(-342.316467, -1476.395630, 30.745728, 277.795288),   brand = "Globe Oil"},
        [16] = {coords = vector4(642.197815, 260.373627, 103.284302, 59.527554),      brand = "Globe Oil"},
        [17] = {coords = vector4(1778.109863, 3325.780273, 41.428589, 300.472443),    brand = "Globe Oil",  price = 20000},
        [18] = {coords = vector4(265.846161, 2598.224121, 44.832275, 8.503937),       brand = "Globe Oil",  price = 20000},
        [19] = {coords = vector4(1039.371460, 2664.184570, 39.541382, 0.000000),      brand = "Globe Oil",  price = 20000},
        [20] = {coords = vector4(-1819.621948, 797.380249, 138.129639, 300.472443),   brand = "LTD Gasoline"},
        [21] = {coords = vector4(1167.296753, -323.802185, 69.247559, 283.464569),    brand = "LTD Gasoline"},
        [22] = {coords = vector4(-703.424194, -935.367004, 19.203613, 93.543304),     brand = "LTD Gasoline"},
        [23] = {coords = vector4(-52.430771, -1770.606567, 29.161865, 48.188972),     brand = "LTD Gasoline"},
        [24] = {coords = vector4(1694.795654, 4924.035156, 42.220459, 53.858269),     brand = "LTD Gasoline", price = 20000},
    },

    -- TIER 3: Restaurant (22 locations)
    restaurant = {
        [1]  = {coords = vector4(537.059326, 102.224182, 96.561157, 164.409454),      brand = "Pizza This"},
        [2]  = {coords = vector4(-1529.353882, -908.808777, 10.155273, 133.228333),   brand = "Pizza This"},
        [3]  = {coords = vector4(288.712097, -963.982422, 29.414673, 5.669291),       brand = "Pizza This"},
        [4]  = {coords = vector4(482.940674, 71.920883, 96.409546, 314.645660),       brand = "Pizza This"},
        [5]  = {coords = vector4(222.804398, -19.991207, 74.976562, 181.417328),      brand = "Pizza This"},
        [6]  = {coords = vector4(-1682.558228, -1096.747192, 13.137695, 184.251968),  brand = "Cluckin' Bell"},
        [7]  = {coords = vector4(-139.358246, -255.771423, 43.585327, 297.637787),    brand = "Cluckin' Bell"},
        [8]  = {coords = vector4(-181.015381, -1429.041748, 31.301880, 294.803162),   brand = "Cluckin' Bell"},
        [9]  = {coords = vector4(-1689.270264, -1090.285767, 13.137695, 141.732285),  brand = "Burger Shot"},
        [10] = {coords = vector4(-1178.175781, -891.837341, 13.744385, 311.811035),   brand = "Burger Shot"},
        [11] = {coords = vector4(-1553.617554, -440.980225, 40.518677, 229.606293),   brand = "Taco Bomb"},
        [12] = {coords = vector4(-658.852722, -676.707703, 31.520874, 317.480316),    brand = "Taco Bomb"},
        [13] = {coords = vector4(-1198.391235, -789.995605, 16.406616, 130.393707),   brand = "Taco Bomb"},
        [14] = {coords = vector4(-1533.138428, -454.496704, 35.885010, 328.818909),   brand = "Wigwam Burger"},
        [15] = {coords = vector4(-857.340637, -1140.158203, 6.970703, 204.094498),    brand = "Wigwam Burger"},
        [16] = {coords = vector4(-1544.109863, -468.237366, 35.463745, 172.913391),   brand = "Up-n-Atom Burger"},
        [17] = {coords = vector4(79.885712, 275.261536, 110.209473, 198.425201),      brand = "Up-n-Atom Burger"},
        [18] = {coords = vector4(1588.971436, 6449.907715, 25.303345, 153.070862),    brand = "Up-n-Atom Burger", price = 35000},
        [19] = {coords = vector4(-587.406616, -872.136230, 25.842529, 354.330719),    brand = "Lucky Plucker"},
        [20] = {coords = vector4(131.736267, -1464.079102, 29.347290, 56.692913),     brand = "Lucky Plucker"},
        [21] = {coords = vector4(167.723083, -1635.059326, 29.279907, 36.850395),     brand = "Bishop's Chicken"},
        [22] = {coords = vector4(2579.103271, 464.861542, 108.625610, 178.582672),    brand = "Bishop's Chicken"},
    },

    -- TIER 4: Laundromat (9 locations)
    laundromat = {
        [1] = {coords = vector4(85.213188, -1549.833008, 29.583130, 45.354328),       brand = "Suds Law Laundromat"},
        [2] = {coords = vector4(-1412.373657, -383.010986, 36.761230, 308.976379),    brand = "Panache Laundering"},
        [3] = {coords = vector4(509.802185, -1459.424194, 29.448364, 337.322845),     brand = "Panache Laundering"},
        [4] = {coords = vector4(218.637360, -19.885712, 69.887939, 161.574799),       brand = "Coin-Op Laundry"},
        [5] = {coords = vector4(169.661545, -1507.424194, 29.246094, 133.228333),     brand = "Go And Wash"},
        [6] = {coords = vector4(216.092300, -1523.881348, 29.279907, 274.960632),     brand = "Sheet Yourself Laundromat"},
        [7] = {coords = vector4(436.153839, -2087.156006, 21.697388, 223.937012),     brand = "Avalon Laundry & Dry Cleaners"},
        [8] = {coords = vector4(-52.219780, 6458.874512, 31.487183, 48.188972),       brand = "No Marks Cleaners",  price = 45000},
        [9] = {coords = vector4(-3053.973633, 635.986816, 7.391968, 291.968506),      brand = "No Marks Cleaners",  price = 45000},
    },

    -- TIER 5: Bar (8 locations)
    bar = {
        [1] = {coords = vector4(495.613190, -1540.536255, 29.279907, 235.275589),     brand = "Hi-Men"},
        [2] = {coords = vector4(255.309891, -1012.325256, 29.263062, 70.866142),      brand = "Shenanigan's Bar"},
        [3] = {coords = vector4(218.795609, 302.729675, 105.575806, 263.622070),      brand = "Singleton's"},
        [4] = {coords = vector4(1986.276978, 3055.529785, 47.208008, 221.102371),     brand = "Yellow Jack Inn",    price = 60000},
        [5] = {coords = vector4(-262.153839, 6291.428711, 31.487183, 226.771667),     brand = "The Bay Bar",        price = 60000},
        [6] = {coords = vector4(-131.248352, 6378.632812, 32.177979, 127.559052),     brand = "Mojito Inn",         price = 60000},
        [7] = {coords = vector4(-554.808777, 273.810974, 82.997070, 147.401581),      brand = "Tequi-la-la"},
        [8] = {coords = vector4(1217.591187, -417.969238, 67.764893, 42.519684),      brand = "Mirror Park Tavern"},
    },

    -- TIER 6: Nightclub (5 locations)
    nightclub = {
        [1] = {coords = vector4(-1390.773682, -588.092285, 30.223389, 28.346457),     brand = "Bahama Mamas"},
        [2] = {coords = vector4(-430.681305, -23.406591, 46.213867, 252.283463),      brand = "Cockatoos"},
        [3] = {coords = vector4(-575.050537, 239.221985, 82.676880, 0.000000),        brand = "The Lust Resort"},
        [4] = {coords = vector4(-741.797791, 247.292313, 77.318726, 184.251968),      brand = "Society"},
        [5] = {coords = vector4(232.246155, -1096.338501, 29.279907, 85.039368),      brand = "The Vault"},
    },

    -- TIER 7: Strip Club (4 locations)
    stripclub = {
        [1] = {coords = vector4(93.112091, -1292.268188, 29.263062, 300.472443),      brand = "Vanilla Unicorn"},
        [2] = {coords = vector4(-378.553833, 218.637360, 83.654175, 2.834646),        brand = "Hornbills"},
        [3] = {coords = vector4(225.810989, 337.041748, 105.592651, 5.669291),        brand = "Pitchers"},
        [4] = {coords = vector4(-301.767029, 6254.637207, 31.504028, 229.606293),     brand = "The Hen House",      price = 120000},
    },

    -- TIER 8: Car Wash (2 locations)
    carwash = {
        [1] = {coords = vector4(-2.716480, -1396.892334, 29.246094, 90.708656),       brand = "Hands On Car Wash"},
        [2] = {coords = vector4(162.052750, -1717.463745, 29.279907, 209.763779),     brand = "Ronnie's Luxury Car Wash"},
    },

    -- TIER 9: Casino (1 location)
    casino = {
        [1] = {coords = vector4(931.186829, 35.920883, 81.093018, 11.338582),         brand = "The Diamond Casino"},
    },
}