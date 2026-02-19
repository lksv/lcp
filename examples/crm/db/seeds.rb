# Wait for metadata to load and tables to be created
LcpRuby::Engine.load_metadata!

Country = LcpRuby.registry.model_for("country")
Region = LcpRuby.registry.model_for("region")
City = LcpRuby.registry.model_for("city")
DealCategory = LcpRuby.registry.model_for("deal_category")
Company = LcpRuby.registry.model_for("company")
Contact = LcpRuby.registry.model_for("contact")
Deal = LcpRuby.registry.model_for("deal")

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
DealCategory.create!(name: "Inbound", parent: new_biz)
DealCategory.create!(name: "Outbound", parent: new_biz)
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
# COMPANIES (5 original + address data on 2)
# ============================================================================

# Get country/region/city references for address assignment
cz = countries["CZE"]
cz_jm = regions["CZE_Jihomoravský"]
brno = City.find_by(name: "Brno")

sk = countries["SVK"]
sk_ba = regions["SVK_Bratislavský"]
bratislava = City.find_by(name: "Bratislava")

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

# ============================================================================
# CONTACTS (5, unchanged)
# ============================================================================

john = Contact.create!(first_name: "John", last_name: "Smith", email: "john@acme.example.com", phone: "+1-555-0101", position: "CTO", company: acme)
jane = Contact.create!(first_name: "Jane", last_name: "Doe", email: "jane@globex.example.com", phone: "+1-555-0201", position: "VP Engineering", company: globex)
bob = Contact.create!(first_name: "Bob", last_name: "Wilson", email: "bob@initech.example.com", phone: "+1-555-0301", position: "Director of IT", company: initech)
alice = Contact.create!(first_name: "Alice", last_name: "Johnson", email: "alice@wayne.example.com", phone: "+1-555-0401", position: "CFO", company: wayne)
tony = Contact.create!(first_name: "Tony", last_name: "Martinez", email: "tony@stark.example.com", phone: "+1-555-0501", position: "CEO", company: stark)

# ============================================================================
# DEALS (6 original, 2 with deal_category)
# ============================================================================

Deal.create!(title: "Enterprise License - Acme", stage: "negotiation", value: 150000.00, company: acme, contact: john, deal_category: new_biz)
Deal.create!(title: "Consulting Package - Globex", stage: "proposal", value: 75000.00, company: globex, contact: jane, deal_category: consulting)
Deal.create!(title: "SaaS Migration - Initech", stage: "qualified", value: 200000.00, company: initech, contact: bob)
Deal.create!(title: "Financial Platform - Wayne", stage: "closed_won", value: 500000.00, company: wayne, contact: alice)
Deal.create!(title: "Hardware Supply - Stark", stage: "lead", value: 50000.00, company: stark, contact: tony)
Deal.create!(title: "Support Contract - Acme", stage: "closed_lost", value: 30000.00, company: acme, contact: john)

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
