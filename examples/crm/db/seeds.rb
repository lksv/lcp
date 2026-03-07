# Wait for metadata to load and tables to be created
LcpRuby::Engine.load_metadata!

Country = LcpRuby.registry.model_for("country")
Region = LcpRuby.registry.model_for("region")
City = LcpRuby.registry.model_for("city")
DealCategory = LcpRuby.registry.model_for("deal_category")
Company = LcpRuby.registry.model_for("company")
Contact = LcpRuby.registry.model_for("contact")
Deal = LcpRuby.registry.model_for("deal")
Activity = LcpRuby.registry.model_for("activity")
SavedFilter = LcpRuby.registry.model_for("saved_filter")

# ============================================================================
# COUNTRIES (12 total, 2 inactive)
# ============================================================================

countries_data = [
  { name: "Czech Republic", code: "CZE", active: true },
  { name: "Slovakia", code: "SVK", active: true },
  { name: "Germany", code: "DEU", active: true },
  { name: "Austria", code: "AUT", active: true },
  { name: "Poland", code: "POL", active: true },
  { name: "Hungary", code: "HUN", active: true },
  { name: "France", code: "FRA", active: true },
  { name: "Spain", code: "ESP", active: true },
  { name: "Italy", code: "ITA", active: true },
  { name: "United Kingdom", code: "GBR", active: true },
  { name: "Norway", code: "NOR", active: false },
  { name: "Iceland", code: "ISL", active: false }
]

countries = {}
countries_data.each do |data|
  countries[data[:code]] = Country.create!(data)
end

# ============================================================================
# REGIONS (~81 total)
# ============================================================================

regions_data = {
  "CZE" => [
    "Praha", "Středočeský", "Jihočeský", "Plzeňský", "Karlovarský",
    "Ústecký", "Liberecký", "Královéhradecký", "Pardubický", "Vysočina",
    "Jihomoravský", "Olomoucký", "Zlínský", "Moravskoslezský"
  ],
  "SVK" => [
    "Bratislavský", "Trnavský", "Trenčiansky", "Nitriansky",
    "Žilinský", "Banskobystrický", "Prešovský", "Košický"
  ],
  "DEU" => [
    "Bayern", "Berlin", "Hamburg", "Hessen", "Niedersachsen",
    "Nordrhein-Westfalen", "Sachsen", "Baden-Württemberg",
    "Brandenburg", "Schleswig-Holstein"
  ],
  "AUT" => [
    "Wien", "Oberösterreich", "Niederösterreich", "Steiermark", "Tirol"
  ],
  "POL" => [
    "Mazowieckie", "Małopolskie", "Wielkopolskie", "Śląskie",
    "Dolnośląskie", "Łódzkie", "Pomorskie", "Podkarpackie"
  ],
  "HUN" => [
    "Budapest", "Pest", "Borsod-Abaúj-Zemplén", "Hajdú-Bihar", "Baranya"
  ],
  "FRA" => [
    "Île-de-France", "Provence-Alpes-Côte d'Azur", "Auvergne-Rhône-Alpes",
    "Occitanie", "Nouvelle-Aquitaine", "Bretagne",
    "Hauts-de-France", "Grand Est"
  ],
  "ESP" => [
    "Madrid", "Cataluña", "Andalucía", "Valencia",
    "País Vasco", "Galicia"
  ],
  "ITA" => [
    "Lazio", "Lombardia", "Campania", "Veneto",
    "Piemonte", "Emilia-Romagna"
  ],
  "GBR" => [
    "England", "Scotland", "Wales",
    "Northern Ireland", "Greater London", "South East England"
  ],
  "NOR" => [
    "Oslo", "Vestland", "Trøndelag"
  ],
  "ISL" => [
    "Höfuðborgarsvæðið", "Suðurland"
  ]
}

regions = {}
regions_data.each do |code, names|
  names.each do |name|
    key = "#{code}_#{name}"
    regions[key] = Region.create!(name: name, country: countries[code])
  end
end

# ============================================================================
# CITIES (~600 total)
# ============================================================================

cities_data = {
  # Czech Republic
  "CZE_Praha" => [
    [ "Praha 1", 30000 ], [ "Praha 2", 50000 ], [ "Praha 3", 72000 ], [ "Praha 4", 130000 ],
    [ "Praha 5", 84000 ], [ "Praha 6", 100000 ], [ "Praha 7", 43000 ], [ "Praha 8", 103000 ],
    [ "Praha 9", 57000 ], [ "Praha 10", 109000 ], [ "Praha 11", 78000 ], [ "Praha 12", 55000 ],
    [ "Praha 13", 61000 ], [ "Praha 14", 44000 ], [ "Praha 15", 33000 ]
  ],
  "CZE_Středočeský" => [
    [ "Kladno", 69000 ], [ "Mladá Boleslav", 44000 ], [ "Příbram", 33000 ],
    [ "Kolín", 31000 ], [ "Kutná Hora", 20000 ], [ "Mělník", 19000 ],
    [ "Beroun", 19000 ], [ "Benešov", 16000 ], [ "Nymburk", 15000 ],
    [ "Rakovník", 16000 ], [ "Poděbrady", 13000 ], [ "Brandýs nad Labem", 19000 ],
    [ "Čáslav", 10000 ], [ "Slaný", 15000 ], [ "Neratovice", 16000 ]
  ],
  "CZE_Jihočeský" => [
    [ "České Budějovice", 94000 ], [ "Tábor", 34000 ], [ "Písek", 30000 ],
    [ "Strakonice", 23000 ], [ "Jindřichův Hradec", 22000 ], [ "Prachatice", 11000 ],
    [ "Český Krumlov", 13000 ], [ "Třeboň", 8500 ], [ "Milevsko", 8800 ],
    [ "Vimperk", 7500 ], [ "Dačice", 7300 ], [ "Blatná", 6600 ]
  ],
  "CZE_Plzeňský" => [
    [ "Plzeň", 174000 ], [ "Klatovy", 22000 ], [ "Rokycany", 14000 ],
    [ "Domažlice", 11000 ], [ "Tachov", 12000 ], [ "Sušice", 11000 ],
    [ "Horšovský Týn", 4800 ], [ "Nepomuk", 3900 ], [ "Stříbro", 7500 ],
    [ "Přeštice", 6500 ], [ "Kralovice", 3400 ]
  ],
  "CZE_Karlovarský" => [
    [ "Karlovy Vary", 49000 ], [ "Cheb", 32000 ], [ "Sokolov", 23000 ],
    [ "Mariánské Lázně", 13000 ], [ "Ostrov", 17000 ], [ "Aš", 13000 ],
    [ "Františkovy Lázně", 5200 ], [ "Jáchymov", 3500 ], [ "Chodov", 13000 ]
  ],
  "CZE_Ústecký" => [
    [ "Ústí nad Labem", 93000 ], [ "Most", 63000 ], [ "Teplice", 50000 ],
    [ "Děčín", 49000 ], [ "Chomutov", 48000 ], [ "Litoměřice", 24000 ],
    [ "Louny", 18000 ], [ "Kadaň", 18000 ], [ "Bílina", 15000 ],
    [ "Žatec", 19000 ], [ "Roudnice nad Labem", 13000 ]
  ],
  "CZE_Liberecký" => [
    [ "Liberec", 104000 ], [ "Jablonec nad Nisou", 45000 ], [ "Česká Lípa", 36000 ],
    [ "Turnov", 14000 ], [ "Semily", 8600 ], [ "Nový Bor", 12000 ],
    [ "Tanvald", 6800 ], [ "Železný Brod", 6300 ], [ "Frýdlant", 7500 ],
    [ "Doksy", 5100 ]
  ],
  "CZE_Královéhradecký" => [
    [ "Hradec Králové", 93000 ], [ "Trutnov", 30000 ], [ "Náchod", 20000 ],
    [ "Jičín", 16000 ], [ "Rychnov nad Kněžnou", 11000 ], [ "Dvůr Králové nad Labem", 16000 ],
    [ "Vrchlabí", 12000 ], [ "Jaroměř", 12000 ], [ "Broumov", 7800 ],
    [ "Nová Paka", 9200 ], [ "Hořice", 8700 ]
  ],
  "CZE_Pardubický" => [
    [ "Pardubice", 91000 ], [ "Chrudim", 23000 ], [ "Svitavy", 17000 ],
    [ "Ústí nad Orlicí", 14000 ], [ "Česká Třebová", 15000 ], [ "Vysoké Mýto", 12000 ],
    [ "Litomyšl", 10000 ], [ "Lanškroun", 10000 ], [ "Polička", 8700 ],
    [ "Hlinsko", 9800 ], [ "Moravská Třebová", 10000 ]
  ],
  "CZE_Vysočina" => [
    [ "Jihlava", 51000 ], [ "Třebíč", 36000 ], [ "Žďár nad Sázavou", 21000 ],
    [ "Havlíčkův Brod", 23000 ], [ "Pelhřimov", 16000 ], [ "Humpolec", 11000 ],
    [ "Chotěboř", 9300 ], [ "Velké Meziříčí", 12000 ], [ "Nové Město na Moravě", 10000 ],
    [ "Světlá nad Sázavou", 6800 ], [ "Bystřice nad Pernštejnem", 8300 ]
  ],
  "CZE_Jihomoravský" => [
    [ "Brno", 382000 ], [ "Znojmo", 34000 ], [ "Hodonín", 25000 ],
    [ "Břeclav", 25000 ], [ "Vyškov", 21000 ], [ "Blansko", 21000 ],
    [ "Boskovice", 11000 ], [ "Kyjov", 11000 ], [ "Veselí nad Moravou", 11000 ],
    [ "Hustopče", 6000 ], [ "Ivančice", 9500 ], [ "Kuřim", 11000 ],
    [ "Tišnov", 9000 ], [ "Slavkov u Brna", 6500 ], [ "Mikulov", 7600 ]
  ],
  "CZE_Olomoucký" => [
    [ "Olomouc", 101000 ], [ "Prostějov", 44000 ], [ "Přerov", 44000 ],
    [ "Šumperk", 27000 ], [ "Jeseník", 11000 ], [ "Zábřeh", 14000 ],
    [ "Hranice", 18000 ], [ "Kojetín", 6000 ], [ "Lipník nad Bečvou", 8300 ],
    [ "Šternberk", 13000 ], [ "Uničov", 12000 ]
  ],
  "CZE_Zlínský" => [
    [ "Zlín", 75000 ], [ "Vsetín", 26000 ], [ "Kroměříž", 29000 ],
    [ "Uherské Hradiště", 25000 ], [ "Valašské Meziříčí", 23000 ],
    [ "Otrokovice", 18000 ], [ "Uherský Brod", 17000 ], [ "Rožnov pod Radhoštěm", 17000 ],
    [ "Holešov", 12000 ], [ "Bystřice pod Hostýnem", 8300 ], [ "Vizovice", 4800 ]
  ],
  "CZE_Moravskoslezský" => [
    [ "Ostrava", 290000 ], [ "Opava", 57000 ], [ "Havířov", 72000 ],
    [ "Frýdek-Místek", 58000 ], [ "Karviná", 52000 ], [ "Nový Jičín", 23000 ],
    [ "Třinec", 36000 ], [ "Bruntál", 16000 ], [ "Krnov", 24000 ],
    [ "Kopřivnice", 22000 ], [ "Český Těšín", 25000 ], [ "Orlová", 29000 ],
    [ "Bohumín", 21000 ], [ "Hlučín", 14000 ], [ "Frenštát pod Radhoštěm", 11000 ]
  ],

  # Slovakia
  "SVK_Bratislavský" => [
    [ "Bratislava", 437000 ], [ "Pezinok", 23000 ], [ "Senec", 20000 ],
    [ "Malacky", 18000 ], [ "Stupava", 11000 ], [ "Svätý Jur", 5200 ],
    [ "Modra", 9000 ], [ "Bernolákovo", 7500 ]
  ],
  "SVK_Trnavský" => [
    [ "Trnava", 66000 ], [ "Piešťany", 28000 ], [ "Dunajská Streda", 23000 ],
    [ "Galanta", 15000 ], [ "Hlohovec", 22000 ], [ "Senica", 20000 ],
    [ "Skalica", 15000 ], [ "Šamorín", 13000 ], [ "Sereď", 16000 ]
  ],
  "SVK_Trenčiansky" => [
    [ "Trenčín", 55000 ], [ "Považská Bystrica", 40000 ], [ "Prievidza", 46000 ],
    [ "Púchov", 18000 ], [ "Dubnica nad Váhom", 25000 ], [ "Partizánske", 22000 ],
    [ "Nové Mesto nad Váhom", 20000 ], [ "Bánovce nad Bebravou", 20000 ],
    [ "Handlová", 17000 ], [ "Ilava", 5600 ], [ "Myjava", 12000 ]
  ],
  "SVK_Nitriansky" => [
    [ "Nitra", 77000 ], [ "Nové Zámky", 39000 ], [ "Komárno", 34000 ],
    [ "Levice", 35000 ], [ "Šaľa", 23000 ], [ "Topoľčany", 26000 ],
    [ "Zlaté Moravce", 12000 ], [ "Štúrovo", 11000 ], [ "Hurbanovo", 7800 ],
    [ "Vráble", 8500 ]
  ],
  "SVK_Žilinský" => [
    [ "Žilina", 81000 ], [ "Martin", 54000 ], [ "Ružomberok", 27000 ],
    [ "Liptovský Mikuláš", 32000 ], [ "Čadca", 25000 ], [ "Dolný Kubín", 19000 ],
    [ "Námestovo", 8000 ], [ "Bytča", 11000 ], [ "Kysucké Nové Mesto", 15000 ],
    [ "Tvrdošín", 9200 ]
  ],
  "SVK_Banskobystrický" => [
    [ "Banská Bystrica", 78000 ], [ "Zvolen", 43000 ], [ "Lučenec", 28000 ],
    [ "Rimavská Sobota", 24000 ], [ "Žiar nad Hronom", 19000 ],
    [ "Banská Štiavnica", 10000 ], [ "Brezno", 22000 ], [ "Veľký Krtíš", 12000 ],
    [ "Detva", 14000 ], [ "Krupina", 7800 ], [ "Kremnica", 5500 ]
  ],
  "SVK_Prešovský" => [
    [ "Prešov", 91000 ], [ "Poprad", 52000 ], [ "Humenné", 34000 ],
    [ "Bardejov", 33000 ], [ "Vranov nad Topľou", 22000 ], [ "Snina", 20000 ],
    [ "Svidník", 12000 ], [ "Kežmarok", 17000 ], [ "Stará Ľubovňa", 16000 ],
    [ "Levoča", 15000 ], [ "Sabinov", 13000 ], [ "Svit", 7300 ],
    [ "Vysoké Tatry", 4300 ], [ "Spišská Nová Ves", 38000 ]
  ],
  "SVK_Košický" => [
    [ "Košice", 240000 ], [ "Michalovce", 40000 ], [ "Spišská Nová Ves", 38000 ],
    [ "Trebišov", 24000 ], [ "Rožňava", 19000 ], [ "Moldava nad Bodvou", 11000 ],
    [ "Gelnica", 6200 ], [ "Sobrance", 6800 ], [ "Kráľovský Chlmec", 7600 ],
    [ "Sečovce", 8500 ]
  ],

  # Germany
  "DEU_Bayern" => [
    [ "München", 1472000 ], [ "Nürnberg", 518000 ], [ "Augsburg", 296000 ],
    [ "Regensburg", 153000 ], [ "Ingolstadt", 138000 ], [ "Würzburg", 127000 ],
    [ "Fürth", 129000 ], [ "Erlangen", 112000 ], [ "Bamberg", 77000 ],
    [ "Bayreuth", 75000 ], [ "Landshut", 73000 ], [ "Passau", 53000 ],
    [ "Rosenheim", 64000 ], [ "Kempten", 69000 ], [ "Aschaffenburg", 72000 ]
  ],
  "DEU_Berlin" => [
    [ "Berlin Mitte", 384000 ], [ "Berlin Charlottenburg", 342000 ],
    [ "Berlin Kreuzberg", 291000 ], [ "Berlin Neukölln", 327000 ],
    [ "Berlin Pankow", 410000 ], [ "Berlin Steglitz", 309000 ],
    [ "Berlin Tempelhof", 352000 ], [ "Berlin Spandau", 245000 ]
  ],
  "DEU_Hamburg" => [
    [ "Hamburg-Mitte", 310000 ], [ "Hamburg-Altona", 274000 ],
    [ "Hamburg-Eimsbüttel", 264000 ], [ "Hamburg-Nord", 316000 ],
    [ "Hamburg-Wandsbek", 435000 ], [ "Hamburg-Bergedorf", 130000 ],
    [ "Hamburg-Harburg", 170000 ]
  ],
  "DEU_Hessen" => [
    [ "Frankfurt am Main", 753000 ], [ "Wiesbaden", 278000 ], [ "Kassel", 201000 ],
    [ "Darmstadt", 159000 ], [ "Offenbach am Main", 130000 ], [ "Hanau", 97000 ],
    [ "Marburg", 77000 ], [ "Gießen", 90000 ], [ "Fulda", 68000 ],
    [ "Bad Homburg", 54000 ], [ "Rüsselsheim", 65000 ]
  ],
  "DEU_Niedersachsen" => [
    [ "Hannover", 536000 ], [ "Braunschweig", 249000 ], [ "Osnabrück", 165000 ],
    [ "Oldenburg", 170000 ], [ "Göttingen", 119000 ], [ "Wolfsburg", 124000 ],
    [ "Salzgitter", 105000 ], [ "Hildesheim", 101000 ], [ "Delmenhorst", 78000 ],
    [ "Wilhelmshaven", 76000 ], [ "Lüneburg", 76000 ], [ "Celle", 69000 ],
    [ "Emden", 50000 ]
  ],
  "DEU_Nordrhein-Westfalen" => [
    [ "Köln", 1086000 ], [ "Düsseldorf", 621000 ], [ "Dortmund", 588000 ],
    [ "Essen", 583000 ], [ "Duisburg", 498000 ], [ "Bochum", 365000 ],
    [ "Wuppertal", 355000 ], [ "Bielefeld", 334000 ], [ "Bonn", 331000 ],
    [ "Münster", 315000 ], [ "Gelsenkirchen", 260000 ], [ "Mönchengladbach", 261000 ],
    [ "Aachen", 249000 ], [ "Krefeld", 228000 ], [ "Oberhausen", 210000 ]
  ],
  "DEU_Sachsen" => [
    [ "Leipzig", 597000 ], [ "Dresden", 556000 ], [ "Chemnitz", 245000 ],
    [ "Zwickau", 89000 ], [ "Plauen", 64000 ], [ "Görlitz", 56000 ],
    [ "Freiberg", 41000 ], [ "Bautzen", 39000 ], [ "Pirna", 38000 ],
    [ "Meißen", 28000 ]
  ],
  "DEU_Baden-Württemberg" => [
    [ "Stuttgart", 635000 ], [ "Mannheim", 309000 ], [ "Karlsruhe", 308000 ],
    [ "Freiburg", 231000 ], [ "Heidelberg", 160000 ], [ "Ulm", 127000 ],
    [ "Heilbronn", 126000 ], [ "Pforzheim", 126000 ], [ "Reutlingen", 116000 ],
    [ "Esslingen", 94000 ], [ "Ludwigsburg", 93000 ], [ "Tübingen", 91000 ],
    [ "Konstanz", 85000 ], [ "Sindelfingen", 65000 ]
  ],
  "DEU_Brandenburg" => [
    [ "Potsdam", 183000 ], [ "Cottbus", 99000 ], [ "Brandenburg an der Havel", 72000 ],
    [ "Frankfurt (Oder)", 58000 ], [ "Oranienburg", 47000 ], [ "Falkensee", 44000 ],
    [ "Eberswalde", 40000 ], [ "Bernau", 40000 ], [ "Königs Wusterhausen", 38000 ]
  ],
  "DEU_Schleswig-Holstein" => [
    [ "Kiel", 247000 ], [ "Lübeck", 217000 ], [ "Flensburg", 90000 ],
    [ "Neumünster", 80000 ], [ "Norderstedt", 80000 ], [ "Elmshorn", 50000 ],
    [ "Pinneberg", 44000 ], [ "Wedel", 34000 ], [ "Itzehoe", 31000 ],
    [ "Ahrensburg", 34000 ]
  ],

  # Austria
  "AUT_Wien" => [
    [ "Wien Innere Stadt", 16000 ], [ "Wien Leopoldstadt", 105000 ],
    [ "Wien Landstraße", 90000 ], [ "Wien Favoriten", 210000 ],
    [ "Wien Donaustadt", 196000 ], [ "Wien Floridsdorf", 166000 ],
    [ "Wien Liesing", 106000 ], [ "Wien Hietzing", 54000 ],
    [ "Wien Ottakring", 105000 ], [ "Wien Hernals", 57000 ]
  ],
  "AUT_Oberösterreich" => [
    [ "Linz", 207000 ], [ "Wels", 62000 ], [ "Steyr", 38000 ],
    [ "Leonding", 29000 ], [ "Traun", 24000 ], [ "Braunau am Inn", 17000 ],
    [ "Bad Ischl", 14000 ], [ "Vöcklabruck", 12000 ], [ "Ried im Innkreis", 12000 ],
    [ "Gmunden", 13000 ], [ "Enns", 12000 ], [ "Marchtrenk", 14000 ]
  ],
  "AUT_Niederösterreich" => [
    [ "St. Pölten", 55000 ], [ "Wiener Neustadt", 46000 ], [ "Krems", 25000 ],
    [ "Amstetten", 24000 ], [ "Baden", 26000 ], [ "Mödling", 21000 ],
    [ "Schwechat", 19000 ], [ "Korneuburg", 13000 ], [ "Tulln", 16000 ],
    [ "Zwettl", 11000 ], [ "Hollabrunn", 12000 ], [ "Mistelbach", 12000 ]
  ],
  "AUT_Steiermark" => [
    [ "Graz", 291000 ], [ "Leoben", 25000 ], [ "Kapfenberg", 22000 ],
    [ "Bruck an der Mur", 16000 ], [ "Knittelfeld", 13000 ], [ "Leibnitz", 12000 ],
    [ "Weiz", 12000 ], [ "Feldbach", 13000 ], [ "Judenburg", 9300 ],
    [ "Voitsberg", 9800 ], [ "Fürstenfeld", 8500 ], [ "Hartberg", 6800 ]
  ],
  "AUT_Tirol" => [
    [ "Innsbruck", 132000 ], [ "Kufstein", 19000 ], [ "Telfs", 16000 ],
    [ "Schwaz", 14000 ], [ "Hall in Tirol", 14000 ], [ "Wörgl", 14000 ],
    [ "Lienz", 12000 ], [ "Imst", 10000 ], [ "Landeck", 7800 ],
    [ "Kitzbühel", 8200 ], [ "Reutte", 6200 ], [ "Rum", 9200 ]
  ],

  # Poland
  "POL_Mazowieckie" => [
    [ "Warszawa", 1794000 ], [ "Radom", 212000 ], [ "Płock", 119000 ],
    [ "Siedlce", 78000 ], [ "Pruszków", 63000 ], [ "Legionowo", 54000 ],
    [ "Ostrołęka", 52000 ], [ "Piaseczno", 50000 ], [ "Ciechanów", 44000 ],
    [ "Mińsk Mazowiecki", 41000 ], [ "Żyrardów", 40000 ]
  ],
  "POL_Małopolskie" => [
    [ "Kraków", 780000 ], [ "Tarnów", 109000 ], [ "Nowy Sącz", 83000 ],
    [ "Oświęcim", 39000 ], [ "Chrzanów", 37000 ], [ "Olkusz", 36000 ],
    [ "Bochnia", 30000 ], [ "Zakopane", 27000 ], [ "Gorlice", 28000 ],
    [ "Wieliczka", 24000 ], [ "Myślenice", 18000 ]
  ],
  "POL_Wielkopolskie" => [
    [ "Poznań", 534000 ], [ "Kalisz", 101000 ], [ "Konin", 74000 ],
    [ "Piła", 74000 ], [ "Ostrów Wielkopolski", 72000 ], [ "Gniezno", 69000 ],
    [ "Leszno", 64000 ], [ "Śrem", 30000 ], [ "Turek", 28000 ],
    [ "Swarzędz", 31000 ], [ "Luboń", 31000 ]
  ],
  "POL_Śląskie" => [
    [ "Katowice", 292000 ], [ "Częstochowa", 220000 ], [ "Sosnowiec", 199000 ],
    [ "Gliwice", 179000 ], [ "Zabrze", 172000 ], [ "Bytom", 163000 ],
    [ "Bielsko-Biała", 171000 ], [ "Ruda Śląska", 137000 ], [ "Rybnik", 138000 ],
    [ "Tychy", 128000 ], [ "Dąbrowa Górnicza", 119000 ], [ "Chorzów", 108000 ],
    [ "Jaworzno", 91000 ], [ "Mysłowice", 74000 ]
  ],
  "POL_Dolnośląskie" => [
    [ "Wrocław", 643000 ], [ "Wałbrzych", 112000 ], [ "Legnica", 100000 ],
    [ "Jelenia Góra", 80000 ], [ "Lubin", 73000 ], [ "Głogów", 67000 ],
    [ "Świdnica", 57000 ], [ "Bolesławiec", 39000 ], [ "Oleśnica", 37000 ],
    [ "Dzierżoniów", 33000 ], [ "Kłodzko", 27000 ]
  ],
  "POL_Łódzkie" => [
    [ "Łódź", 672000 ], [ "Piotrków Trybunalski", 73000 ], [ "Pabianice", 65000 ],
    [ "Tomaszów Mazowiecki", 63000 ], [ "Bełchatów", 57000 ], [ "Zgierz", 56000 ],
    [ "Skierniewice", 49000 ], [ "Radomsko", 46000 ], [ "Kutno", 44000 ],
    [ "Sieradz", 42000 ], [ "Łask", 18000 ]
  ],
  "POL_Pomorskie" => [
    [ "Gdańsk", 471000 ], [ "Gdynia", 246000 ], [ "Słupsk", 91000 ],
    [ "Tczew", 60000 ], [ "Starogard Gdański", 48000 ], [ "Wejherowo", 50000 ],
    [ "Rumia", 50000 ], [ "Sopot", 36000 ], [ "Malbork", 39000 ],
    [ "Chojnice", 40000 ], [ "Kwidzyn", 39000 ]
  ],
  "POL_Podkarpackie" => [
    [ "Rzeszów", 198000 ], [ "Przemyśl", 60000 ], [ "Stalowa Wola", 60000 ],
    [ "Mielec", 60000 ], [ "Tarnobrzeg", 47000 ], [ "Krosno", 47000 ],
    [ "Dębica", 46000 ], [ "Sanok", 38000 ], [ "Jarosław", 37000 ],
    [ "Jasło", 36000 ], [ "Nisko", 15000 ], [ "Łańcut", 18000 ]
  ],

  # Hungary
  "HUN_Budapest" => [
    [ "Budapest I.", 25000 ], [ "Budapest II.", 88000 ], [ "Budapest III.", 124000 ],
    [ "Budapest IV.", 96000 ], [ "Budapest V.", 27000 ], [ "Budapest VI.", 42000 ],
    [ "Budapest VII.", 62000 ], [ "Budapest VIII.", 81000 ], [ "Budapest IX.", 61000 ],
    [ "Budapest X.", 78000 ], [ "Budapest XI.", 141000 ], [ "Budapest XII.", 57000 ],
    [ "Budapest XIII.", 113000 ], [ "Budapest XIV.", 121000 ]
  ],
  "HUN_Pest" => [
    [ "Érd", 69000 ], [ "Budaörs", 30000 ], [ "Dunakeszi", 44000 ],
    [ "Vác", 34000 ], [ "Gödöllő", 35000 ], [ "Szentendre", 26000 ],
    [ "Százhalombatta", 19000 ], [ "Szigetszentmiklós", 36000 ],
    [ "Vecsés", 22000 ], [ "Gyál", 25000 ]
  ],
  "HUN_Borsod-Abaúj-Zemplén" => [
    [ "Miskolc", 157000 ], [ "Ózd", 34000 ], [ "Kazincbarcika", 27000 ],
    [ "Tiszaújváros", 16000 ], [ "Sárospatak", 12000 ], [ "Szerencs", 9100 ],
    [ "Mezőkövesd", 17000 ], [ "Sajószentpéter", 12000 ], [ "Edelény", 9500 ],
    [ "Putnok", 5800 ]
  ],
  "HUN_Hajdú-Bihar" => [
    [ "Debrecen", 203000 ], [ "Hajdúböszörmény", 31000 ], [ "Hajdúszoboszló", 24000 ],
    [ "Balmazújváros", 17000 ], [ "Berettyóújfalu", 15000 ], [ "Hajdúnánás", 17000 ],
    [ "Püspökladány", 15000 ], [ "Hajdúhadház", 13000 ], [ "Derecske", 9500 ],
    [ "Nádudvar", 8700 ]
  ],
  "HUN_Baranya" => [
    [ "Pécs", 145000 ], [ "Komló", 24000 ], [ "Mohács", 18000 ],
    [ "Szigetvár", 11000 ], [ "Siklós", 10000 ], [ "Pécsvárad", 4200 ],
    [ "Harkány", 4100 ], [ "Bóly", 3800 ], [ "Villány", 2600 ],
    [ "Sellye", 2800 ]
  ],

  # France
  "FRA_Île-de-France" => [
    [ "Paris", 2161000 ], [ "Boulogne-Billancourt", 120000 ], [ "Saint-Denis", 113000 ],
    [ "Argenteuil", 111000 ], [ "Montreuil", 109000 ], [ "Nanterre", 96000 ],
    [ "Créteil", 91000 ], [ "Versailles", 85000 ], [ "Vitry-sur-Seine", 94000 ],
    [ "Colombes", 85000 ], [ "Asnières-sur-Seine", 87000 ]
  ],
  "FRA_Provence-Alpes-Côte d'Azur" => [
    [ "Marseille", 870000 ], [ "Nice", 341000 ], [ "Toulon", 172000 ],
    [ "Aix-en-Provence", 143000 ], [ "Avignon", 91000 ], [ "Antibes", 74000 ],
    [ "Cannes", 74000 ], [ "La Seyne-sur-Mer", 65000 ], [ "Hyères", 56000 ],
    [ "Fréjus", 54000 ], [ "Arles", 52000 ]
  ],
  "FRA_Auvergne-Rhône-Alpes" => [
    [ "Lyon", 516000 ], [ "Saint-Étienne", 172000 ], [ "Grenoble", 158000 ],
    [ "Villeurbanne", 150000 ], [ "Clermont-Ferrand", 143000 ],
    [ "Vénissieux", 66000 ], [ "Valence", 63000 ], [ "Chambéry", 60000 ],
    [ "Annecy", 128000 ], [ "Bourg-en-Bresse", 42000 ], [ "Roanne", 35000 ]
  ],
  "FRA_Occitanie" => [
    [ "Toulouse", 479000 ], [ "Montpellier", 290000 ], [ "Nîmes", 151000 ],
    [ "Perpignan", 121000 ], [ "Béziers", 78000 ], [ "Carcassonne", 47000 ],
    [ "Narbonne", 54000 ], [ "Albi", 49000 ], [ "Tarbes", 41000 ],
    [ "Sète", 44000 ], [ "Castres", 41000 ]
  ],
  "FRA_Nouvelle-Aquitaine" => [
    [ "Bordeaux", 257000 ], [ "Limoges", 132000 ], [ "Poitiers", 89000 ],
    [ "La Rochelle", 77000 ], [ "Pau", 77000 ], [ "Mérignac", 72000 ],
    [ "Pessac", 64000 ], [ "Angoulême", 42000 ], [ "Bayonne", 52000 ],
    [ "Brive-la-Gaillarde", 47000 ], [ "Niort", 59000 ]
  ],
  "FRA_Bretagne" => [
    [ "Rennes", 216000 ], [ "Brest", 139000 ], [ "Quimper", 63000 ],
    [ "Lorient", 57000 ], [ "Vannes", 53000 ], [ "Saint-Malo", 46000 ],
    [ "Saint-Brieuc", 45000 ], [ "Lanester", 23000 ], [ "Fougères", 20000 ],
    [ "Lannion", 19000 ], [ "Concarneau", 18000 ]
  ],
  "FRA_Hauts-de-France" => [
    [ "Lille", 233000 ], [ "Amiens", 135000 ], [ "Roubaix", 98000 ],
    [ "Dunkerque", 87000 ], [ "Tourcoing", 97000 ], [ "Calais", 72000 ],
    [ "Boulogne-sur-Mer", 42000 ], [ "Arras", 41000 ], [ "Douai", 39000 ],
    [ "Lens", 31000 ], [ "Valenciennes", 43000 ], [ "Beauvais", 56000 ]
  ],
  "FRA_Grand Est" => [
    [ "Strasbourg", 280000 ], [ "Reims", 183000 ], [ "Metz", 117000 ],
    [ "Mulhouse", 109000 ], [ "Nancy", 105000 ], [ "Colmar", 70000 ],
    [ "Troyes", 61000 ], [ "Charleville-Mézières", 48000 ], [ "Épinal", 32000 ],
    [ "Thionville", 42000 ], [ "Haguenau", 35000 ]
  ],

  # Spain
  "ESP_Madrid" => [
    [ "Madrid", 3266000 ], [ "Móstoles", 208000 ], [ "Alcalá de Henares", 196000 ],
    [ "Fuenlabrada", 196000 ], [ "Leganés", 189000 ], [ "Getafe", 183000 ],
    [ "Alcorcón", 170000 ], [ "Torrejón de Ardoz", 131000 ],
    [ "Parla", 132000 ], [ "Alcobendas", 117000 ], [ "Coslada", 83000 ]
  ],
  "ESP_Cataluña" => [
    [ "Barcelona", 1621000 ], [ "L'Hospitalet de Llobregat", 264000 ],
    [ "Badalona", 223000 ], [ "Terrassa", 223000 ], [ "Sabadell", 213000 ],
    [ "Lleida", 139000 ], [ "Tarragona", 135000 ], [ "Mataró", 129000 ],
    [ "Santa Coloma de Gramenet", 120000 ], [ "Reus", 107000 ],
    [ "Girona", 103000 ], [ "Cornellà de Llobregat", 88000 ]
  ],
  "ESP_Andalucía" => [
    [ "Sevilla", 684000 ], [ "Málaga", 578000 ], [ "Córdoba", 326000 ],
    [ "Granada", 232000 ], [ "Jerez de la Frontera", 213000 ], [ "Almería", 200000 ],
    [ "Huelva", 143000 ], [ "Cádiz", 116000 ], [ "Jaén", 112000 ],
    [ "Marbella", 147000 ], [ "Dos Hermanas", 135000 ], [ "Algeciras", 122000 ]
  ],
  "ESP_Valencia" => [
    [ "Valencia", 792000 ], [ "Alicante", 337000 ], [ "Elche", 234000 ],
    [ "Castellón de la Plana", 174000 ], [ "Torrevieja", 83000 ],
    [ "Orihuela", 78000 ], [ "Benidorm", 69000 ], [ "Gandia", 74000 ],
    [ "Paterna", 71000 ], [ "Sagunto", 67000 ], [ "Torrent", 82000 ]
  ],
  "ESP_País Vasco" => [
    [ "Bilbao", 346000 ], [ "Vitoria-Gasteiz", 253000 ], [ "San Sebastián", 187000 ],
    [ "Barakaldo", 100000 ], [ "Getxo", 78000 ], [ "Irun", 63000 ],
    [ "Portugalete", 46000 ], [ "Santurtzi", 46000 ], [ "Basauri", 41000 ],
    [ "Leioa", 31000 ], [ "Durango", 30000 ]
  ],
  "ESP_Galicia" => [
    [ "Vigo", 296000 ], [ "A Coruña", 246000 ], [ "Ourense", 105000 ],
    [ "Lugo", 98000 ], [ "Santiago de Compostela", 98000 ], [ "Pontevedra", 83000 ],
    [ "Ferrol", 66000 ], [ "Narón", 40000 ], [ "Vilagarcía de Arousa", 37000 ],
    [ "Carballo", 31000 ], [ "Culleredo", 30000 ]
  ],

  # Italy
  "ITA_Lazio" => [
    [ "Roma", 2873000 ], [ "Latina", 127000 ], [ "Guidonia Montecelio", 89000 ],
    [ "Fiumicino", 82000 ], [ "Aprilia", 74000 ], [ "Viterbo", 67000 ],
    [ "Tivoli", 57000 ], [ "Velletri", 53000 ], [ "Civitavecchia", 53000 ],
    [ "Anzio", 55000 ], [ "Frosinone", 46000 ]
  ],
  "ITA_Lombardia" => [
    [ "Milano", 1372000 ], [ "Brescia", 196000 ], [ "Monza", 124000 ],
    [ "Bergamo", 122000 ], [ "Como", 84000 ], [ "Varese", 81000 ],
    [ "Busto Arsizio", 84000 ], [ "Sesto San Giovanni", 81000 ],
    [ "Pavia", 73000 ], [ "Cremona", 72000 ], [ "Vigevano", 63000 ],
    [ "Lecco", 48000 ], [ "Mantova", 49000 ]
  ],
  "ITA_Campania" => [
    [ "Napoli", 959000 ], [ "Salerno", 132000 ], [ "Giugliano in Campania", 124000 ],
    [ "Torre del Greco", 85000 ], [ "Casoria", 78000 ], [ "Caserta", 76000 ],
    [ "Castellammare di Stabia", 66000 ], [ "Afragola", 65000 ],
    [ "Benevento", 59000 ], [ "Portici", 55000 ], [ "Ercolano", 53000 ]
  ],
  "ITA_Veneto" => [
    [ "Venezia", 261000 ], [ "Verona", 258000 ], [ "Padova", 211000 ],
    [ "Vicenza", 112000 ], [ "Treviso", 85000 ], [ "Rovigo", 52000 ],
    [ "Bassano del Grappa", 44000 ], [ "Chioggia", 49000 ], [ "Mira", 38000 ],
    [ "San Donà di Piave", 42000 ], [ "Jesolo", 26000 ]
  ],
  "ITA_Piemonte" => [
    [ "Torino", 870000 ], [ "Novara", 104000 ], [ "Alessandria", 94000 ],
    [ "Asti", 76000 ], [ "Moncalieri", 57000 ], [ "Cuneo", 56000 ],
    [ "Collegno", 50000 ], [ "Rivoli", 49000 ], [ "Nichelino", 48000 ],
    [ "Settimo Torinese", 47000 ], [ "Biella", 45000 ], [ "Vercelli", 46000 ]
  ],
  "ITA_Emilia-Romagna" => [
    [ "Bologna", 392000 ], [ "Parma", 198000 ], [ "Modena", 185000 ],
    [ "Reggio Emilia", 172000 ], [ "Ravenna", 159000 ], [ "Rimini", 150000 ],
    [ "Ferrara", 133000 ], [ "Forlì", 118000 ], [ "Piacenza", 104000 ],
    [ "Cesena", 97000 ], [ "Imola", 70000 ], [ "Faenza", 59000 ]
  ],

  # United Kingdom
  "GBR_England" => [
    [ "Birmingham", 1141000 ], [ "Leeds", 793000 ], [ "Sheffield", 584000 ],
    [ "Manchester", 553000 ], [ "Bristol", 463000 ], [ "Leicester", 355000 ],
    [ "Coventry", 371000 ], [ "Nottingham", 322000 ], [ "Newcastle", 302000 ],
    [ "Sunderland", 275000 ], [ "Brighton", 229000 ], [ "Plymouth", 263000 ],
    [ "Southampton", 253000 ], [ "Reading", 230000 ]
  ],
  "GBR_Scotland" => [
    [ "Glasgow", 633000 ], [ "Edinburgh", 527000 ], [ "Aberdeen", 197000 ],
    [ "Dundee", 148000 ], [ "Paisley", 77000 ], [ "East Kilbride", 75000 ],
    [ "Livingston", 57000 ], [ "Hamilton", 54000 ], [ "Cumbernauld", 52000 ],
    [ "Kirkcaldy", 49000 ], [ "Perth", 47000 ], [ "Inverness", 50000 ],
    [ "Stirling", 37000 ]
  ],
  "GBR_Wales" => [
    [ "Cardiff", 362000 ], [ "Swansea", 246000 ], [ "Newport", 155000 ],
    [ "Wrexham", 65000 ], [ "Barry", 55000 ], [ "Neath", 50000 ],
    [ "Cwmbran", 48000 ], [ "Bridgend", 41000 ], [ "Llanelli", 25000 ],
    [ "Merthyr Tydfil", 32000 ], [ "Caerphilly", 41000 ], [ "Pontypridd", 33000 ]
  ],
  "GBR_Northern Ireland" => [
    [ "Belfast", 343000 ], [ "Derry", 84000 ], [ "Lisburn", 72000 ],
    [ "Newtownabbey", 66000 ], [ "Bangor", 61000 ], [ "Craigavon", 56000 ],
    [ "Ballymena", 30000 ], [ "Newry", 27000 ], [ "Carrickfergus", 28000 ],
    [ "Coleraine", 25000 ], [ "Omagh", 22000 ]
  ],
  "GBR_Greater London" => [
    [ "City of London", 9400 ], [ "Westminster", 261000 ], [ "Camden", 270000 ],
    [ "Islington", 240000 ], [ "Hackney", 281000 ], [ "Tower Hamlets", 324000 ],
    [ "Southwark", 318000 ], [ "Lambeth", 326000 ], [ "Wandsworth", 327000 ],
    [ "Hammersmith", 185000 ], [ "Kensington", 156000 ], [ "Croydon", 385000 ],
    [ "Bromley", 332000 ], [ "Barnet", 395000 ]
  ],
  "GBR_South East England" => [
    [ "Southampton", 253000 ], [ "Portsmouth", 215000 ], [ "Oxford", 152000 ],
    [ "Milton Keynes", 229000 ], [ "Slough", 164000 ], [ "Guildford", 78000 ],
    [ "Canterbury", 55000 ], [ "Maidstone", 107000 ], [ "Crawley", 113000 ],
    [ "Basingstoke", 113000 ], [ "Woking", 105000 ], [ "Aylesbury", 59000 ],
    [ "Eastbourne", 103000 ], [ "Hastings", 92000 ], [ "Tunbridge Wells", 59000 ]
  ],

  # Norway (inactive country)
  "NOR_Oslo" => [
    [ "Oslo", 694000 ], [ "Bærum", 127000 ], [ "Asker", 94000 ],
    [ "Drammen", 69000 ], [ "Lillestrøm", 82000 ], [ "Fredrikstad", 82000 ],
    [ "Sarpsborg", 57000 ], [ "Moss", 49000 ], [ "Ski", 30000 ]
  ],
  "NOR_Vestland" => [
    [ "Bergen", 285000 ], [ "Askøy", 29000 ], [ "Stord", 19000 ],
    [ "Os", 20000 ], [ "Fjell", 26000 ], [ "Haugesund", 37000 ],
    [ "Karmøy", 42000 ], [ "Bømlo", 12000 ], [ "Voss", 14000 ]
  ],
  "NOR_Trøndelag" => [
    [ "Trondheim", 205000 ], [ "Steinkjer", 24000 ], [ "Stjørdal", 24000 ],
    [ "Levanger", 20000 ], [ "Verdal", 15000 ], [ "Namsos", 13000 ],
    [ "Orkland", 18000 ], [ "Melhus", 17000 ], [ "Malvik", 14000 ]
  ],

  # Iceland (inactive country)
  "ISL_Höfuðborgarsvæðið" => [
    [ "Reykjavík", 133000 ], [ "Kópavogur", 38000 ], [ "Hafnarfjörður", 29000 ],
    [ "Garðabær", 18000 ], [ "Mosfellsbær", 12000 ], [ "Seltjarnarnes", 4700 ],
    [ "Álftanes", 3100 ]
  ],
  "ISL_Suðurland" => [
    [ "Selfoss", 7800 ], [ "Vestmannaeyjar", 4500 ], [ "Hveragerði", 2700 ],
    [ "Þorlákshöfn", 2600 ], [ "Hella", 800 ], [ "Vik", 700 ]
  ]
}

cities_data.each do |key, city_list|
  region = regions[key]
  next unless region

  city_list.each do |city_name, pop|
    City.create!(name: city_name, population: pop, region: region)
  end
end

# ============================================================================
# DEAL CATEGORIES (15 in tree)
# ============================================================================

sales = DealCategory.create!(name: "Sales")
new_biz = DealCategory.create!(name: "New Business", parent: sales)
inbound = DealCategory.create!(name: "Inbound", parent: new_biz)
outbound = DealCategory.create!(name: "Outbound", parent: new_biz)
upsell = DealCategory.create!(name: "Upsell", parent: sales)
cross_sell = DealCategory.create!(name: "Cross-sell", parent: sales)

services = DealCategory.create!(name: "Services")
consulting = DealCategory.create!(name: "Consulting", parent: services)
implementation = DealCategory.create!(name: "Implementation", parent: services)
support = DealCategory.create!(name: "Support", parent: services)

partnership = DealCategory.create!(name: "Partnership")
reseller = DealCategory.create!(name: "Reseller", parent: partnership)
technology = DealCategory.create!(name: "Technology", parent: partnership)
integration = DealCategory.create!(name: "Integration", parent: partnership)

# ============================================================================
# COMPANIES (15 total)
# ============================================================================

# Get country/region/city references for address assignment
cz = countries["CZE"]
cz_jm = regions["CZE_Jihomoravský"]
brno = City.find_by(name: "Brno")

sk = countries["SVK"]
sk_ba = regions["SVK_Bratislavský"]
bratislava = City.find_by(name: "Bratislava")

de = countries["DEU"]
de_by = regions["DEU_Bayern"]
munich = City.find_by(name: "München")

gb = countries["GBR"]
gb_gl = regions["GBR_Greater London"]
westminster = City.find_by(name: "Westminster")

acme = Company.create!(
  name: "Acme Corp", industry: "technology",
  website: "https://acme.example.com", phone: "+1-555-0100",
  address_type: "known", country: cz, region: cz_jm, city: brno,
  street: "Masarykova 123"
)
globex = Company.create!(
  name: "Globex Corporation", industry: "manufacturing",
  website: "https://globex.example.com", phone: "+1-555-0200",
  address_type: "known", country: sk, region: sk_ba, city: bratislava,
  street: "Hlavná 456"
)
initech = Company.create!(
  name: "Initech", industry: "technology",
  website: "https://initech.example.com", phone: "+1-555-0300"
)
wayne = Company.create!(
  name: "Wayne Enterprises", industry: "finance",
  website: "https://wayne.example.com", phone: "+1-555-0400"
)
stark = Company.create!(
  name: "Stark Industries", industry: "technology",
  website: "https://stark.example.com", phone: "+1-555-0500"
)
umbrella = Company.create!(
  name: "Umbrella Corp", industry: "healthcare",
  website: "https://umbrella.example.com", phone: "+1-555-0600"
)
oscorp = Company.create!(
  name: "Oscorp Industries", industry: "technology",
  website: "https://oscorp.example.com", phone: "+1-555-0700",
  address_type: "known", country: de, region: de_by, city: munich,
  street: "Marienplatz 42"
)
lexcorp = Company.create!(
  name: "LexCorp", industry: "finance",
  website: "https://lexcorp.example.com", phone: "+1-555-0800"
)
cyberdyne = Company.create!(
  name: "Cyberdyne Systems", industry: "technology",
  website: "https://cyberdyne.example.com", phone: "+1-555-0900"
)
tyrell = Company.create!(
  name: "Tyrell Corporation", industry: "technology",
  website: "https://tyrell.example.com", phone: "+1-555-1000",
  address_type: "known", country: gb, region: gb_gl, city: westminster,
  street: "221B Baker Street"
)
soylent = Company.create!(
  name: "Soylent Corp", industry: "manufacturing",
  website: "https://soylent.example.com", phone: "+1-555-1100"
)
aperture = Company.create!(
  name: "Aperture Science", industry: "technology",
  website: "https://aperture.example.com", phone: "+1-555-1200"
)
weyland = Company.create!(
  name: "Weyland-Yutani", industry: "manufacturing",
  website: "https://weyland.example.com", phone: "+1-555-1300"
)
ingen = Company.create!(
  name: "InGen", industry: "healthcare",
  website: "https://ingen.example.com", phone: "+1-555-1400"
)
massive = Company.create!(
  name: "Massive Dynamic", industry: "technology",
  website: "https://massive.example.com", phone: "+1-555-1500"
)

all_companies = [ acme, globex, initech, wayne, stark, umbrella, oscorp, lexcorp,
                 cyberdyne, tyrell, soylent, aperture, weyland, ingen, massive ]

# ============================================================================
# CONTACTS (30 total, 2 per company)
# ============================================================================

john = Contact.create!(first_name: "John", last_name: "Smith", email: "john@acme.example.com", phone: "+1-555-0101", position: "CTO", company: acme, skills: %w[Cloud DevOps Java])
sarah = Contact.create!(first_name: "Sarah", last_name: "Connor", email: "sarah@acme.example.com", phone: "+1-555-0102", position: "VP Engineering", company: acme, skills: %w[Ruby Python DevOps])

jane = Contact.create!(first_name: "Jane", last_name: "Doe", email: "jane@globex.example.com", phone: "+1-555-0201", position: "VP Engineering", company: globex, skills: %w[JavaScript Cloud])
marcus = Contact.create!(first_name: "Marcus", last_name: "Wright", email: "marcus@globex.example.com", phone: "+1-555-0202", position: "Production Manager", company: globex, skills: %w[Sales Marketing])

bob = Contact.create!(first_name: "Bob", last_name: "Wilson", email: "bob@initech.example.com", phone: "+1-555-0301", position: "Director of IT", company: initech, skills: %w[Java Cloud DevOps])
peter = Contact.create!(first_name: "Peter", last_name: "Gibbons", email: "peter@initech.example.com", phone: "+1-555-0302", position: "Software Engineer", company: initech, skills: %w[Ruby JavaScript Python])

alice = Contact.create!(first_name: "Alice", last_name: "Johnson", email: "alice@wayne.example.com", phone: "+1-555-0401", position: "CFO", company: wayne, skills: %w[Finance Legal])
bruce = Contact.create!(first_name: "Bruce", last_name: "Thomas", email: "bruce@wayne.example.com", phone: "+1-555-0402", position: "Head of R&D", company: wayne, skills: %w[Python Cloud])

tony = Contact.create!(first_name: "Tony", last_name: "Martinez", email: "tony@stark.example.com", phone: "+1-555-0501", position: "CEO", company: stark, skills: %w[Sales Marketing])
pepper = Contact.create!(first_name: "Virginia", last_name: "Potts", email: "pepper@stark.example.com", phone: "+1-555-0502", position: "COO", company: stark, skills: %w[Finance Marketing Legal])

albert = Contact.create!(first_name: "Albert", last_name: "Wesker", email: "albert@umbrella.example.com", phone: "+1-555-0601", position: "Head of Research", company: umbrella, skills: %w[Python Java])
jill = Contact.create!(first_name: "Jill", last_name: "Valentine", email: "jill@umbrella.example.com", phone: "+1-555-0602", position: "Lab Director", company: umbrella, skills: %w[Python])

norman = Contact.create!(first_name: "Norman", last_name: "Osborn", email: "norman@oscorp.example.com", phone: "+1-555-0701", position: "CEO", company: oscorp, skills: %w[Sales Finance])
gwen = Contact.create!(first_name: "Gwen", last_name: "Stacy", email: "gwen@oscorp.example.com", phone: "+1-555-0702", position: "Research Scientist", company: oscorp, skills: %w[Python Ruby JavaScript])

lex = Contact.create!(first_name: "Lex", last_name: "Luthor", email: "lex@lexcorp.example.com", phone: "+1-555-0801", position: "CEO", company: lexcorp, skills: %w[Finance Legal Sales])
mercy = Contact.create!(first_name: "Mercy", last_name: "Graves", email: "mercy@lexcorp.example.com", phone: "+1-555-0802", position: "VP Operations", company: lexcorp, skills: %w[Marketing Sales])

miles = Contact.create!(first_name: "Miles", last_name: "Dyson", email: "miles@cyberdyne.example.com", phone: "+1-555-0901", position: "VP Product", company: cyberdyne, skills: %w[Python Java Cloud DevOps])
kate = Contact.create!(first_name: "Kate", last_name: "Brewster", email: "kate@cyberdyne.example.com", phone: "+1-555-0902", position: "Sales Director", company: cyberdyne, skills: %w[Sales Marketing])

eldon = Contact.create!(first_name: "Eldon", last_name: "Tyrell", email: "eldon@tyrell.example.com", phone: "+1-555-1001", position: "Founder", company: tyrell, skills: %w[Cloud DevOps])
rachael = Contact.create!(first_name: "Rachael", last_name: "Rosen", email: "rachael@tyrell.example.com", phone: "+1-555-1002", position: "Product Manager", company: tyrell, skills: %w[Marketing Sales JavaScript])

sol = Contact.create!(first_name: "Sol", last_name: "Roth", email: "sol@soylent.example.com", phone: "+1-555-1101", position: "VP Supply Chain", company: soylent, skills: %w[Finance])
frank = Contact.create!(first_name: "Frank", last_name: "Thorn", email: "frank@soylent.example.com", phone: "+1-555-1102", position: "Operations Manager", company: soylent, skills: %w[Sales])

cave = Contact.create!(first_name: "Cave", last_name: "Johnson", email: "cave@aperture.example.com", phone: "+1-555-1201", position: "CEO", company: aperture, skills: %w[Sales Marketing Legal])
caroline = Contact.create!(first_name: "Caroline", last_name: "McLain", email: "caroline@aperture.example.com", phone: "+1-555-1202", position: "Head of Testing", company: aperture, skills: %w[Python JavaScript DevOps])

karl = Contact.create!(first_name: "Karl", last_name: "Bishop", email: "karl@weyland.example.com", phone: "+1-555-1301", position: "Colony Director", company: weyland, skills: %w[Sales Legal])
ellen = Contact.create!(first_name: "Ellen", last_name: "Ripley", email: "ellen@weyland.example.com", phone: "+1-555-1302", position: "Chief Engineer", company: weyland, skills: %w[Java Cloud DevOps])

john_h = Contact.create!(first_name: "John", last_name: "Hammond", email: "john@ingen.example.com", phone: "+1-555-1401", position: "Founder", company: ingen, skills: %w[Finance Marketing])
henry = Contact.create!(first_name: "Henry", last_name: "Wu", email: "henry@ingen.example.com", phone: "+1-555-1402", position: "Chief Geneticist", company: ingen, skills: %w[Python Java])

walter = Contact.create!(first_name: "Walter", last_name: "Bishop", email: "walter@massive.example.com", phone: "+1-555-1501", position: "Chief Scientist", company: massive, skills: %w[Python Ruby Cloud])
olivia = Contact.create!(first_name: "Olivia", last_name: "Dunham", email: "olivia@massive.example.com", phone: "+1-555-1502", position: "VP Security", company: massive, skills: %w[DevOps Cloud Legal])

all_contacts = [ john, sarah, jane, marcus, bob, peter, alice, bruce, tony, pepper,
                albert, jill, norman, gwen, lex, mercy, miles, kate, eldon, rachael,
                sol, frank, cave, caroline, karl, ellen, john_h, henry, walter, olivia ]

# ============================================================================
# DEALS (42 total)
# ============================================================================

# Create a dummy PDF for deals that require document attachments
dummy_pdf = StringIO.new("%PDF-1.4 dummy")

deal1 = Deal.new(title: "Enterprise License - Acme", stage: "negotiation", value: 150000.00, company: acme, contact: john, deal_category: new_biz, tags: %w[enterprise strategic long-term])
deal1.documents.attach(io: StringIO.new("%PDF-1.4 dummy"), filename: "contract.pdf", content_type: "application/pdf")
deal1.save!

deal2 = Deal.new(title: "Consulting Package - Globex", stage: "proposal", value: 75000.00, company: globex, contact: jane, deal_category: consulting, tags: %w[partner pilot])
deal2.documents.attach(io: StringIO.new("%PDF-1.4 dummy"), filename: "proposal.pdf", content_type: "application/pdf")
deal2.save!

Deal.create!(title: "SaaS Migration - Initech", stage: "qualified", value: 200000.00, company: initech, contact: bob, deal_category: implementation, tags: %w[enterprise urgent])

deal4 = Deal.new(title: "Financial Platform - Wayne", stage: "closed_won", value: 500000.00, company: wayne, contact: alice, tags: %w[enterprise strategic])
deal4.documents.attach(io: StringIO.new("%PDF-1.4 dummy"), filename: "agreement.pdf", content_type: "application/pdf")
deal4.save!

Deal.create!(title: "Hardware Supply - Stark", stage: "lead", value: 50000.00, company: stark, contact: tony, tags: %w[pilot])
Deal.create!(title: "Support Contract - Acme", stage: "closed_lost", value: 30000.00, company: acme, contact: john, tags: %w[renewal])

# Helper: stages requiring document attachments
def create_deal_with_docs!(attrs)
  deal = Deal.new(attrs)
  deal.documents.attach(io: StringIO.new("%PDF-1.4 dummy"), filename: "#{deal.title.parameterize}.pdf", content_type: "application/pdf")
  deal.save!
  deal
end

# New deals for expanded seed data
create_deal_with_docs!(title: "Clinical Data Platform - Umbrella", stage: "proposal", value: 320000.00, company: umbrella, contact: albert, deal_category: new_biz, expected_close_date: 45.days.from_now, tags: %w[enterprise strategic])
Deal.create!(title: "Lab Management System - Umbrella", stage: "qualified", value: 85000.00, company: umbrella, contact: jill, deal_category: consulting, tags: %w[pilot])
create_deal_with_docs!(title: "Biotech Research License - Oscorp", stage: "negotiation", value: 450000.00, company: oscorp, contact: norman, deal_category: new_biz, expected_close_date: 20.days.from_now, tags: %w[enterprise urgent long-term])
Deal.create!(title: "Genome Sequencing Tools - Oscorp", stage: "lead", value: 120000.00, company: oscorp, contact: gwen, tags: %w[proof-of-concept])
create_deal_with_docs!(title: "Financial Analytics Suite - LexCorp", stage: "closed_won", value: 680000.00, company: lexcorp, contact: lex, deal_category: upsell, tags: %w[enterprise upsell strategic])
create_deal_with_docs!(title: "Portfolio Management - LexCorp", stage: "proposal", value: 195000.00, company: lexcorp, contact: mercy, expected_close_date: 60.days.from_now, tags: %w[partner])
create_deal_with_docs!(title: "AI Safety Monitoring - Cyberdyne", stage: "negotiation", value: 275000.00, company: cyberdyne, contact: miles, deal_category: technology, expected_close_date: 15.days.from_now, tags: %w[urgent strategic])
Deal.create!(title: "Predictive Maintenance - Cyberdyne", stage: "qualified", value: 140000.00, company: cyberdyne, contact: kate, deal_category: implementation, tags: %w[pilot])
create_deal_with_docs!(title: "Replicant Analytics - Tyrell", stage: "closed_won", value: 500000.00, company: tyrell, contact: eldon, deal_category: new_biz, tags: %w[enterprise long-term])
create_deal_with_docs!(title: "Cloud Infrastructure - Tyrell", stage: "proposal", value: 210000.00, company: tyrell, contact: rachael, expected_close_date: 35.days.from_now, tags: %w[partner strategic])
Deal.create!(title: "Supply Chain Optimization - Soylent", stage: "lead", value: 95000.00, company: soylent, contact: sol)
Deal.create!(title: "Factory Automation - Soylent", stage: "qualified", value: 180000.00, company: soylent, contact: frank, deal_category: implementation, tags: %w[enterprise])
create_deal_with_docs!(title: "Testing Platform - Aperture", stage: "negotiation", value: 350000.00, company: aperture, contact: cave, deal_category: technology, expected_close_date: 10.days.from_now, tags: %w[urgent proof-of-concept])
Deal.create!(title: "Portal Technology License - Aperture", stage: "closed_lost", value: 550000.00, company: aperture, contact: caroline, tags: %w[enterprise])
create_deal_with_docs!(title: "Colony Management System - Weyland", stage: "proposal", value: 425000.00, company: weyland, contact: karl, deal_category: new_biz, expected_close_date: 50.days.from_now, tags: %w[enterprise strategic long-term])
Deal.create!(title: "Deep Space Analytics - Weyland", stage: "qualified", value: 160000.00, company: weyland, contact: ellen, deal_category: consulting, tags: %w[pilot])
create_deal_with_docs!(title: "Genetic Database - InGen", stage: "closed_won", value: 290000.00, company: ingen, contact: john_h, deal_category: new_biz, tags: %w[enterprise])
Deal.create!(title: "Cloning Research Platform - InGen", stage: "lead", value: 175000.00, company: ingen, contact: henry, tags: %w[proof-of-concept])
create_deal_with_docs!(title: "Cross-dimensional Analytics - Massive", stage: "negotiation", value: 320000.00, company: massive, contact: walter, deal_category: technology, expected_close_date: 25.days.from_now, tags: %w[strategic urgent])
create_deal_with_docs!(title: "Security Monitoring - Massive", stage: "proposal", value: 135000.00, company: massive, contact: olivia, expected_close_date: 40.days.from_now, tags: %w[partner])

# Additional deals for volume and variety
Deal.create!(title: "DevOps Transformation - Acme", stage: "qualified", value: 110000.00, company: acme, contact: sarah, deal_category: consulting, tags: %w[urgent])
create_deal_with_docs!(title: "Mobile App Development - Initech", stage: "proposal", value: 65000.00, company: initech, contact: peter, deal_category: new_biz, expected_close_date: 55.days.from_now, tags: %w[pilot])
create_deal_with_docs!(title: "Wealth Management Platform - Wayne", stage: "negotiation", value: 380000.00, company: wayne, contact: bruce, deal_category: upsell, expected_close_date: 18.days.from_now, tags: %w[enterprise upsell strategic])
create_deal_with_docs!(title: "Hardware Refresh - Stark", stage: "closed_won", value: 240000.00, company: stark, contact: pepper, deal_category: cross_sell, tags: %w[renewal])
Deal.create!(title: "Integration Services - Globex", stage: "qualified", value: 55000.00, company: globex, contact: marcus, deal_category: integration, tags: %w[partner])
Deal.create!(title: "Data Warehouse - Oscorp", stage: "closed_lost", value: 190000.00, company: oscorp, contact: gwen, deal_category: implementation, tags: %w[enterprise])
Deal.create!(title: "Compliance Toolkit - LexCorp", stage: "lead", value: 45000.00, company: lexcorp, contact: mercy, tags: %w[government])
create_deal_with_docs!(title: "Robotics Platform - Cyberdyne", stage: "closed_won", value: 370000.00, company: cyberdyne, contact: kate, deal_category: technology, tags: %w[enterprise strategic long-term])
create_deal_with_docs!(title: "Support Renewal - Tyrell", stage: "proposal", value: 28000.00, company: tyrell, contact: rachael, deal_category: support, expected_close_date: 12.days.from_now, tags: %w[renewal])
create_deal_with_docs!(title: "Quality Assurance System - Soylent", stage: "negotiation", value: 105000.00, company: soylent, contact: sol, deal_category: consulting, expected_close_date: 30.days.from_now)
Deal.create!(title: "Research Portal - Aperture", stage: "qualified", value: 78000.00, company: aperture, contact: caroline, deal_category: new_biz, tags: %w[pilot proof-of-concept])
Deal.create!(title: "Fleet Management - Weyland", stage: "closed_lost", value: 220000.00, company: weyland, contact: ellen)
create_deal_with_docs!(title: "Park Operations Suite - InGen", stage: "proposal", value: 310000.00, company: ingen, contact: henry, deal_category: implementation, expected_close_date: 65.days.from_now, tags: %w[enterprise long-term])
Deal.create!(title: "Fringe Science Platform - Massive", stage: "lead", value: 250000.00, company: massive, contact: walter, deal_category: technology, tags: %w[strategic proof-of-concept])
create_deal_with_docs!(title: "Threat Intelligence - Massive", stage: "closed_won", value: 155000.00, company: massive, contact: olivia, deal_category: consulting, tags: %w[partner])
Deal.create!(title: "ERP Integration - Globex", stage: "lead", value: 8500.00, company: globex, contact: jane, deal_category: integration)

# ============================================================================
# ACTIVITIES (55 total)
# ============================================================================

now = Time.current

# Completed activities (past)
Activity.create!(subject: "Discovery call with Acme CTO", activity_type: "call", company: acme, contact: john, deal: deal1, scheduled_at: now - 14.days, completed: true, completed_at: now - 14.days + 30.minutes, outcome: "Identified key requirements for enterprise license. Budget approved internally.")
Activity.create!(subject: "Product demo for Globex", activity_type: "meeting", company: globex, contact: jane, deal: deal2, scheduled_at: now - 10.days, completed: true, completed_at: now - 10.days + 2.hours, outcome: "Demo went well. Jane requested custom pricing for manufacturing modules.")
Activity.create!(subject: "Follow-up email to Initech", activity_type: "email", company: initech, contact: bob, scheduled_at: now - 7.days, completed: true, completed_at: now - 7.days + 15.minutes, outcome: "Sent technical specification document. Bob will review with team.")
Activity.create!(subject: "Contract review meeting - Wayne", activity_type: "meeting", company: wayne, contact: alice, deal: deal4, scheduled_at: now - 21.days, completed: true, completed_at: now - 21.days + 3.hours, outcome: "Legal review complete. Contract signed. Deal closed won.")
Activity.create!(subject: "Introductory call with Stark CEO", activity_type: "call", company: stark, contact: tony, scheduled_at: now - 5.days, completed: true, completed_at: now - 5.days + 45.minutes, outcome: "Tony interested in expanding hardware supply contract. Will schedule demo.")
Activity.create!(subject: "Research notes on Umbrella requirements", activity_type: "note", company: umbrella, contact: albert, scheduled_at: now - 3.days, completed: true, completed_at: now - 3.days, outcome: "Umbrella needs HIPAA-compliant platform. Custom security module required.")
Activity.create!(subject: "Pricing proposal email to Oscorp", activity_type: "email", company: oscorp, contact: norman, scheduled_at: now - 8.days, completed: true, completed_at: now - 8.days, outcome: "Sent tiered pricing. Norman asked for volume discount on 3-year commitment.")
Activity.create!(subject: "Technical workshop - Cyberdyne", activity_type: "meeting", company: cyberdyne, contact: miles, scheduled_at: now - 12.days, completed: true, completed_at: now - 12.days + 4.hours, outcome: "Deep dive on AI safety features. Miles impressed with monitoring capabilities.")
Activity.create!(subject: "Needs assessment call - LexCorp", activity_type: "call", company: lexcorp, contact: lex, scheduled_at: now - 6.days, completed: true, completed_at: now - 6.days + 1.hour, outcome: "Lex wants analytics suite expanded to include real-time trading data.")
Activity.create!(subject: "Onboarding kickoff - Tyrell", activity_type: "meeting", company: tyrell, contact: eldon, scheduled_at: now - 30.days, completed: true, completed_at: now - 30.days + 2.hours, outcome: "Onboarding started for Replicant Analytics. Phase 1 deployment in 6 weeks.")
Activity.create!(subject: "Follow-up on proposal - Weyland", activity_type: "call", company: weyland, contact: karl, scheduled_at: now - 4.days, completed: true, completed_at: now - 4.days + 25.minutes, outcome: "Karl reviewing proposal with board. Decision expected next week.")
Activity.create!(subject: "Demo setup notes - Aperture", activity_type: "note", company: aperture, contact: cave, scheduled_at: now - 2.days, completed: true, completed_at: now - 2.days, outcome: "Need to prepare custom demo environment for testing platform showcase.")
Activity.create!(subject: "Success review - Massive Dynamic", activity_type: "meeting", company: massive, contact: olivia, scheduled_at: now - 9.days, completed: true, completed_at: now - 9.days + 1.hour, outcome: "Threat Intelligence deployment successful. Olivia recommends us to other departments.")
Activity.create!(subject: "Renewal reminder email - Tyrell", activity_type: "email", company: tyrell, contact: rachael, scheduled_at: now - 1.day, completed: true, completed_at: now - 1.day, outcome: "Sent support renewal proposal. Rachael confirmed receipt.")
Activity.create!(subject: "Reference call setup - InGen", activity_type: "call", company: ingen, contact: john_h, scheduled_at: now - 15.days, completed: true, completed_at: now - 15.days + 20.minutes, outcome: "John agreed to be a reference customer for genetic database platform.")

# Overdue activities (scheduled in past, not completed)
Activity.create!(subject: "Send revised proposal to Soylent", activity_type: "task", company: soylent, contact: sol, scheduled_at: now - 3.days, completed: false, description: "Revise pricing based on Q4 volume projections and send to Sol.")
Activity.create!(subject: "Follow-up call with Aperture", activity_type: "call", company: aperture, contact: cave, scheduled_at: now - 2.days, completed: false, description: "Discuss testing platform timeline and resource requirements.")
Activity.create!(subject: "Update CRM notes for LexCorp deal", activity_type: "task", company: lexcorp, contact: mercy, scheduled_at: now - 1.day, completed: false, description: "Document latest portfolio management requirements from Mercy.")
Activity.create!(subject: "Email contract addendum to Cyberdyne", activity_type: "email", company: cyberdyne, contact: kate, scheduled_at: now - 4.days, completed: false, description: "Send updated contract terms for robotics platform extension.")
Activity.create!(subject: "Prepare competitive analysis for Oscorp", activity_type: "task", company: oscorp, contact: gwen, scheduled_at: now - 5.days, completed: false, description: "Compare our biotech features against CompetitorX for Gwen's review.")

# Pending activities (today and future)
Activity.create!(subject: "Quarterly review call - Acme", activity_type: "call", company: acme, contact: john, deal: deal1, scheduled_at: now + 1.hour, completed: false, description: "Review Q1 progress and discuss enterprise license expansion.")
Activity.create!(subject: "Product roadmap presentation - Globex", activity_type: "meeting", company: globex, contact: jane, deal: deal2, scheduled_at: now + 2.days, completed: false, description: "Present 2026 product roadmap and discuss manufacturing module priorities.")
Activity.create!(subject: "Technical integration call - Initech", activity_type: "call", company: initech, contact: peter, scheduled_at: now + 3.days, completed: false, description: "Discuss SaaS migration technical requirements with engineering team.")
Activity.create!(subject: "Executive dinner - Wayne Enterprises", activity_type: "meeting", company: wayne, contact: bruce, scheduled_at: now + 5.days, completed: false, description: "Dinner with Wayne R&D head to discuss new wealth management platform.")
Activity.create!(subject: "Send case study to Stark", activity_type: "email", company: stark, contact: pepper, scheduled_at: now + 1.day, completed: false, description: "Share manufacturing customer case study with Virginia.")
Activity.create!(subject: "Compliance review prep for Umbrella", activity_type: "task", company: umbrella, contact: jill, scheduled_at: now + 4.days, completed: false, description: "Prepare HIPAA compliance documentation for lab director review.")
Activity.create!(subject: "Demo day - Oscorp biotech suite", activity_type: "meeting", company: oscorp, contact: norman, scheduled_at: now + 7.days, completed: false, description: "Full demo of biotech research platform for Oscorp leadership team.")
Activity.create!(subject: "Contract negotiation call - LexCorp", activity_type: "call", company: lexcorp, contact: lex, scheduled_at: now + 2.days, completed: false, description: "Final pricing negotiation for portfolio management system.")
Activity.create!(subject: "Architecture review email - Cyberdyne", activity_type: "email", company: cyberdyne, contact: miles, scheduled_at: now + 6.days, completed: false, description: "Send system architecture document for AI safety monitoring platform.")
Activity.create!(subject: "User acceptance testing - Tyrell", activity_type: "meeting", company: tyrell, contact: rachael, scheduled_at: now + 8.days, completed: false, description: "UAT session for cloud infrastructure deployment with product team.")
Activity.create!(subject: "Factory visit - Soylent Corp", activity_type: "meeting", company: soylent, contact: frank, scheduled_at: now + 10.days, completed: false, description: "On-site visit to understand factory automation requirements.")
Activity.create!(subject: "Pilot kickoff - Aperture Science", activity_type: "meeting", company: aperture, contact: cave, scheduled_at: now + 12.days, completed: false, description: "Launch 30-day pilot of testing platform with Aperture team.")
Activity.create!(subject: "Board presentation prep - Weyland", activity_type: "task", company: weyland, contact: karl, scheduled_at: now + 3.days, completed: false, description: "Prepare executive summary for Weyland board meeting presentation.")
Activity.create!(subject: "Research partnership discussion - InGen", activity_type: "meeting", company: ingen, contact: henry, scheduled_at: now + 14.days, completed: false, description: "Explore research partnership for genetic database enhancements.")
Activity.create!(subject: "Security audit findings review - Massive", activity_type: "call", company: massive, contact: olivia, scheduled_at: now + 5.days, completed: false, description: "Review security audit findings and discuss remediation plan.")
Activity.create!(subject: "Prepare training materials for Acme", activity_type: "task", company: acme, contact: sarah, scheduled_at: now + 9.days, completed: false, description: "Create onboarding training deck for Acme engineering team.")
Activity.create!(subject: "Send NDA to Cyberdyne", activity_type: "email", company: cyberdyne, contact: kate, scheduled_at: now + 1.day, completed: false, description: "Send mutual NDA for robotics platform integration details.")
Activity.create!(subject: "Proposal follow-up call - InGen", activity_type: "call", company: ingen, contact: john_h, scheduled_at: now + 6.days, completed: false, description: "Follow up on park operations suite proposal.")
Activity.create!(subject: "Market analysis for Massive Dynamic", activity_type: "task", company: massive, contact: walter, scheduled_at: now + 11.days, completed: false, description: "Complete competitive market analysis for fringe science platform positioning.")
Activity.create!(subject: "Integration planning - Globex", activity_type: "meeting", company: globex, contact: marcus, scheduled_at: now + 15.days, completed: false, description: "Plan ERP integration phases with production management team.")
Activity.create!(subject: "Renewal negotiation prep - Wayne", activity_type: "task", company: wayne, contact: alice, scheduled_at: now + 7.days, completed: false, description: "Prepare renewal terms for financial platform with improved SLA.")
Activity.create!(subject: "Technical deep dive - Soylent QA", activity_type: "meeting", company: soylent, contact: sol, scheduled_at: now + 16.days, completed: false, description: "Deep technical session on quality assurance system integration points.")
Activity.create!(subject: "Competitive positioning email - Aperture", activity_type: "email", company: aperture, contact: caroline, scheduled_at: now + 4.days, completed: false, description: "Send competitive analysis showing advantages of our research portal.")
Activity.create!(subject: "Weekly status update - Stark", activity_type: "email", company: stark, contact: tony, scheduled_at: now + 2.days, completed: false, description: "Send weekly project status update for hardware refresh deployment.")
Activity.create!(subject: "Reference check call - Weyland", activity_type: "call", company: weyland, contact: ellen, scheduled_at: now + 8.days, completed: false, description: "Ellen wants to speak with existing fleet management customer reference.")

# ============================================================================
# SAVED FILTERS (8 total)
# ============================================================================

# Use owner_id: 1 (seeded admin user or first user)
owner_id = 1

# Deal saved filters
SavedFilter.create!(
  name: "High Value Open",
  description: "Open deals worth 50k+ EUR",
  target_presenter: "deal",
  condition_tree: {
    "type" => "group",
    "operator" => "and",
    "conditions" => [
      { "field" => "stage", "operator" => "not_in", "value" => %w[closed_won closed_lost] },
      { "field" => "value", "operator" => "gteq", "value" => "50000" }
    ]
  },
  ql_text: 'stage NOT IN ("closed_won", "closed_lost") AND value >= 50000',
  visibility: "global",
  owner_id: owner_id,
  pinned: true,
  default_filter: true,
  position: 1,
  icon: "trending-up",
  color: "green"
)

SavedFilter.create!(
  name: "Closing This Month",
  description: "Open deals expected to close this month",
  target_presenter: "deal",
  condition_tree: {
    "type" => "group",
    "operator" => "and",
    "conditions" => [
      { "field" => "expected_close_date", "operator" => "this_month" },
      { "field" => "stage", "operator" => "not_in", "value" => %w[closed_won closed_lost] }
    ]
  },
  ql_text: 'expected_close_date IS THIS MONTH AND stage NOT IN ("closed_won", "closed_lost")',
  visibility: "personal",
  owner_id: owner_id,
  pinned: true,
  position: 2,
  icon: "calendar"
)

SavedFilter.create!(
  name: "Won Deals",
  description: "All deals closed as won",
  target_presenter: "deal",
  condition_tree: {
    "type" => "group",
    "operator" => "and",
    "conditions" => [
      { "field" => "stage", "operator" => "eq", "value" => "closed_won" }
    ]
  },
  ql_text: 'stage = "closed_won"',
  visibility: "personal",
  owner_id: owner_id,
  position: 3,
  icon: "award",
  color: "green"
)

SavedFilter.create!(
  name: "Tech Companies",
  description: "Deals from technology companies",
  target_presenter: "deal",
  condition_tree: {
    "type" => "group",
    "operator" => "and",
    "conditions" => [
      { "field" => "company.industry", "operator" => "eq", "value" => "technology" }
    ]
  },
  ql_text: 'company.industry = "technology"',
  visibility: "personal",
  owner_id: owner_id,
  position: 4,
  icon: "cpu"
)

SavedFilter.create!(
  name: "Needs Follow-up",
  description: "Proposal/negotiation deals worth 20k+ needing attention",
  target_presenter: "deal",
  condition_tree: {
    "type" => "group",
    "operator" => "and",
    "conditions" => [
      { "field" => "stage", "operator" => "in", "value" => %w[proposal negotiation] },
      { "field" => "value", "operator" => "gteq", "value" => "20000" }
    ]
  },
  ql_text: 'stage IN ("proposal", "negotiation") AND value >= 20000',
  visibility: "personal",
  owner_id: owner_id,
  pinned: true,
  position: 5,
  icon: "alert-circle",
  color: "orange"
)

# Activity saved filters
SavedFilter.create!(
  name: "Pending Tasks",
  description: "All incomplete tasks",
  target_presenter: "activity",
  condition_tree: {
    "type" => "group",
    "operator" => "and",
    "conditions" => [
      { "field" => "completed", "operator" => "eq", "value" => "false" },
      { "field" => "activity_type", "operator" => "eq", "value" => "task" }
    ]
  },
  ql_text: 'completed = false AND activity_type = "task"',
  visibility: "global",
  owner_id: owner_id,
  pinned: true,
  position: 1,
  icon: "check-square",
  color: "orange"
)

SavedFilter.create!(
  name: "Upcoming Meetings",
  description: "Future meetings not yet completed",
  target_presenter: "activity",
  condition_tree: {
    "type" => "group",
    "operator" => "and",
    "conditions" => [
      { "field" => "activity_type", "operator" => "eq", "value" => "meeting" },
      { "field" => "completed", "operator" => "eq", "value" => "false" }
    ]
  },
  ql_text: 'activity_type = "meeting" AND completed = false',
  visibility: "personal",
  owner_id: owner_id,
  pinned: true,
  position: 2,
  icon: "users",
  color: "purple"
)

SavedFilter.create!(
  name: "My Calls This Week",
  description: "Call activities scheduled for this week",
  target_presenter: "activity",
  condition_tree: {
    "type" => "group",
    "operator" => "and",
    "conditions" => [
      { "field" => "activity_type", "operator" => "eq", "value" => "call" },
      { "field" => "scheduled_at", "operator" => "this_week" }
    ]
  },
  ql_text: 'activity_type = "call" AND scheduled_at IS THIS WEEK',
  visibility: "personal",
  owner_id: owner_id,
  position: 3,
  icon: "phone"
)

# ============================================================================
# Summary
# ============================================================================

puts "Seeded:"
puts "  #{Country.count} countries (#{Country.where(active: false).count} inactive)"
puts "  #{Region.count} regions"
puts "  #{City.count} cities (#{City.where('population >= 10000').count} large, #{City.where('population < 10000').count} small)"
puts "  #{DealCategory.count} deal categories"
puts "  #{Company.count} companies"
puts "  #{Contact.count} contacts"
puts "  #{Deal.count} deals"
puts "  #{Activity.count} activities (#{Activity.where(completed: true).count} completed, #{Activity.where(completed: false).count} pending)"
puts "  #{SavedFilter.count} saved filters"
