"""
Language-specific data and configurations for the Babblelon app.

This file contains compound words and other linguistic data that requires
special handling during translation and syllable processing.
"""

# Thai compound words that should not have syllables translated individually
# These are words where splitting into syllables would create confusing or
# meaningless translations that don't help learners understand the whole word.
KNOWN_THAI_COMPOUNDS = {
    # === COUNTRIES & PLACES ===
    "เกาหลี",      # Korea
    "ญี่ปุ่น",      # Japan  
    "อเมริกา",     # America
    "อังกฤษ",      # England
    "ฝรั่งเศส",    # France
    "เยอรมนี",     # Germany
    "จีน",         # China
    "อิตาลี",      # Italy
    "สเปน",        # Spain
    "รัสเซีย",     # Russia
    "อินเดีย",     # India
    "ออสเตรเลีย",  # Australia
    "แคนาดา",      # Canada
    "เม็กซิโก",    # Mexico
    "บราซิล",      # Brazil
    "อาร์เจนตินา", # Argentina
    "กรุงเทพฯ",    # Bangkok
    "เชียงใหม่",   # Chiang Mai
    "ภูเก็ต",      # Phuket
    
    # === TECHNOLOGY & MODERN ITEMS ===
    "คอมพิวเตอร์",  # Computer
    "โทรศัพท์",    # Telephone
    "โทรทัศน์",    # Television
    "วิทยุ",       # Radio
    "อินเทอร์เน็ต", # Internet
    "เครื่องปรับอากาศ", # Air conditioner
    "ตู้เย็น",     # Refrigerator
    "เครื่องซักผ้า", # Washing machine
    "ไมโครเวฟ",    # Microwave
    "เครื่องเสียง", # Sound system
    "กล้องถ่ายรูป", # Camera
    "โปรเจคเตอร์",  # Projector
    
    # === FOOD & DRINK ===
    "ไอศกรีม",     # Ice cream
    "แฮมเบอร์เกอร์", # Hamburger
    "พิซซ่า",      # Pizza
    "สปาเก็ตตี้",   # Spaghetti
    "แซนด์วิช",    # Sandwich
    "ฮอทดอก",      # Hot dog
    "โดนัท",       # Donut
    "เค้ก",        # Cake
    "คุกกี้",      # Cookie
    "ช็อกโกแลต",   # Chocolate
    "กาแฟ",        # Coffee
    "โคคา-โคลา",   # Coca-Cola
    "เบียร์",      # Beer
    "วิสกี้",      # Whiskey
    
    # === BUILDINGS & PLACES ===
    "โรงแรม",      # Hotel
    "สนามบิน",     # Airport
    "โรงพยาบาล",   # Hospital
    "มหาวิทยาลัย", # University
    "ห้างสรรพสินค้า", # Department store
    "ซูเปอร์มาร์เก็ต", # Supermarket
    "โรงภาพยนตร์", # Movie theater
    "ธนาคาร",      # Bank
    "ไปรษณีย์",    # Post office
    "สถานีรถไฟ",   # Train station
    "สถานีตำรวจ",  # Police station
    "โรงเรียน",    # School
    "ห้องสมุด",    # Library
    "พิพิธภัณฑ์",  # Museum
    "สวนสาธารณะ", # Public park
    "สวนสัตว์",    # Zoo
    "สวนน้ำ",      # Water park
    
    # === VEHICLES ===
    "รถยนต์",      # Automobile
    "รถจักรยาน",   # Bicycle
    "รถมอเตอร์ไซค์", # Motorcycle
    "รถบัส",       # Bus
    "รถไฟ",        # Train
    "เครื่องบิน",   # Airplane
    "เฮลิคอปเตอร์", # Helicopter
    "เรือ",         # Boat/Ship
    "รถแท็กซี่",    # Taxi
    "รถตู้",        # Van
    
    # === ANIMALS ===
    "ช้าง",         # Elephant
    "เสือ",         # Tiger
    "หมี",          # Bear
    "สิงโต",       # Lion
    "ยีราฟ",       # Giraffe
    "ม้าลาย",      # Zebra
    "แรด",         # Rhinoceros
    "ฮิปโปโปเตมัส", # Hippopotamus
    "จิงโจ้",      # Kangaroo
    "ปีนังู",      # Penguin
    "นกแก้ว",      # Parrot
    "ปลาฉลาม",    # Shark
    "ปลาวาฬ",     # Whale
    "ปลาโลมา",    # Dolphin
    
    # === BODY PARTS (compound ones) ===
    "หัวใจ",       # Heart
    "ปอด",         # Lungs
    "ตับ",         # Liver
    "ไต",          # Kidney
    "กระเพาะอาหาร", # Stomach
    "ลำไส้",       # Intestine
    "สมอง",        # Brain
    "กระดูก",      # Bone
    
    # === CLOTHING ===
    "เสื้อผ้า",     # Clothing
    "กางเกง",      # Pants
    "เสื้อเชิ้ต",   # Shirt
    "กระโปรง",     # Skirt
    "ชุดว่ายน้ำ",   # Swimsuit
    "รองเท้า",     # Shoes
    "ถุงเท้า",     # Socks
    "หมวก",        # Hat
    "แว่นตา",      # Eyeglasses
    "นาฬิกา",      # Watch/Clock
    
    # === NATURAL PHENOMENA ===
    "แผ่นดินไหว",  # Earthquake
    "ภูเขาไฟ",     # Volcano
    "น้ำท่วม",      # Flood
    "พายุ",        # Storm
    "ฟ้าร้อง",     # Thunder
    "ฟ้าผ่า",      # Lightning
    "รุ้ง",         # Rainbow
    "หิมะ",        # Snow
    "ลูกเห็บ",     # Hail
    
    # === COMMON GREETINGS & PHRASES ===
    "สวัสดี",      # Hello
    "ขอบคุณ",      # Thank you
    "ขอโทษ",       # Sorry/Excuse me
    "ไม่เป็นไร",   # It's okay/No problem
    "ลาก่อน",      # Goodbye
    "ยินดีที่ได้รู้จัก", # Nice to meet you
    
    # === PROFESSIONS ===
    "แพทย์",       # Doctor
    "พยาบาล",      # Nurse
    "ครูบา",       # Teacher
    "วิศวกร",      # Engineer
    "ทนายความ",    # Lawyer
    "นักบิน",      # Pilot
    "นักดับเพลิง", # Firefighter
    "ตำรวจ",       # Police officer
    "ทหาร",        # Soldier
    "นักข่าว",     # Journalist
    "นักเขียน",    # Writer
    "นักแสดง",     # Actor
    "นักร้อง",     # Singer
    "นักกีฬา",     # Athlete
    
    # === SPORTS & ACTIVITIES ===
    "ฟุตบอล",      # Football/Soccer
    "บาสเกตบอล",  # Basketball
    "เทนนิส",      # Tennis
    "แบดมินตัน",   # Badminton
    "ว่ายน้ำ",      # Swimming
    "วิ่ง",         # Running
    "ปีนเขา",      # Mountain climbing
    "ตกปลา",       # Fishing
    "กอล์ฟ",       # Golf
    "โยคะ",        # Yoga
    
    # === ACADEMIC SUBJECTS ===
    "คณิตศาสตร์",  # Mathematics
    "วิทยาศาสตร์", # Science
    "ฟิสิกส์",     # Physics
    "เคมี",        # Chemistry
    "ชีววิทยา",    # Biology
    "ประวัติศาสตร์", # History
    "ภูมิศาสตร์",  # Geography
    "ปรัชญา",      # Philosophy
    "จิตวิทยา",    # Psychology
    "เศรษฐศาสตร์", # Economics
}

# Future: Add other language compound data here
# KNOWN_VIETNAMESE_COMPOUNDS = {...}
# KNOWN_CHINESE_COMPOUNDS = {...} 