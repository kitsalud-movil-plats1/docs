import json, os
P="fd5a:fc7e:d716"
OUT=os.path.join(os.path.dirname(__file__),'..','diagramas')
def t(lines,size=12):
    return '<p style="font-size:%dpx;text-align:center">'%size + "<br>".join(lines) + "</p>"
shapes=[];lines=[]
def box(id,x,y,w,h,txt,fill="#FFFFFF",stroke="#555555",typ="rectangle",size=12,dash="solid"):
    shapes.append({"id":id,"type":typ,"boundingBox":{"x":x,"y":y,"w":w,"h":h},"text":t(txt,size),
                   "style":{"fill":{"type":"color","color":fill},"stroke":{"color":stroke,"width":2,"style":dash}}})
def line(id,a,b,pa=None,pb=None,label=None,lpos=0.5,dash="solid",width=2,color="#333333",arrow="none"):
    e1={"type":"shapeEndpoint","style":"none","shapeId":a}; e2={"type":"shapeEndpoint","style":arrow,"shapeId":b}
    if pa: e1["position"]={"x":pa[0],"y":pa[1]}; e2["position"]={"x":pb[0],"y":pb[1]}
    l={"id":id,"lineType":"straight","endpoint1":e1,"endpoint2":e2,"stroke":{"color":color,"width":width,"style":dash}}
    if label: l["text"]=[{"text":'<span style="font-size:11px">%s</span>'%label,"position":lpos,"side":"middle"}]
    lines.append(l)
def container(id,typ,x,y,w,h,title,fill,stroke,width=2):
    shapes.append({"id":id,"type":typ,"boundingBox":{"x":x,"y":y,"w":w,"h":h},"containerTitle":{"text":title},
      "style":{"fill":{"type":"color","color":fill},"stroke":{"color":stroke,"width":width,"style":"solid"}}})
def save(name,title):
    doc={"version":1,"pages":[{"id":"p1","title":title,"shapes":shapes,"lines":lines}]}
    open(os.path.join(OUT,name),'w').write(json.dumps(doc,ensure_ascii=False,separators=(",",":")))
    print(name,len(json.dumps(doc)))
    shapes.clear(); lines.clear()

# ---------------- Diagrama lógico ----------------
# Kit container first (z-order back)
container("kit","roundedRectangleContainer",20,330,2060,1310,
  "KIT MÓVIL - nodos KVM (kvm01 + kvm02/kvm03 opcionales) + switch SG350X + AP multi-SSID (UPS lógica)","#FAFAFA","#2E7D32",3)

vlans=[
 ("v10","VLAN 10 - Gestión","#FDECEA","#C62828","10.20.10.0/24","Estático + reservas DHCP (solo cable)",[
   ("sw01",["<b>sw01</b> - Cisco SG350X-24","10.20.10.2 | %s:10::2"%P,"trunk 802.1Q hacia kvm01 / ap01"]),
   ("ap01",["<b>ap01</b> - AP multi-SSID","10.20.10.3 | %s:10::3"%P,"SSID Clínica (30) y Comunidad (40)"]),
   ("kvm01",["<b>kvm01</b> - nodo principal (KVM)","10.20.10.5 | %s:10::5"%P,"aloja fw01 e infra01; NUT (UPS simulada)"]),
   ("kvm0x",["<b>kvm02 / kvm03</b> - nodos opcionales","10.20.10.6-7 | %s:10::6-7"%P,"laptops del grupo (perfiles 2 y 3)"]),
   ("adm",["<b>Equipos del personal técnico</b>","reservas 10.20.10.100-119 (cable)","SSH/HTTPS de gestión solo desde aquí"])]),
 ("v20","VLAN 20 - Servidores","#E8F0FE","#1565C0","10.20.20.0/24","Estático (IPv6 espejo de IPv4)",[
   ("infra01",["<b>infra01</b> - BIND9 + Chrony","10.20.20.10 | %s:20::10"%P,"ns1 / ntp.salud.movil (VM infra01)"]),
   ("dc01",["<b>dc01</b> - Samba AD DC","10.20.20.11 | %s:20::11"%P,"ad.salud.movil (rol en la VM infra01)"]),
   ("files01",["<b>files01</b> - SMB, NFS, backups","10.20.20.12 | %s:20::12"%P,"archivos.salud.movil (rol en la VM ops01)"]),
   ("apps01",["<b>apps01</b> - DHIS2 + PostgreSQL","10.20.20.13 | %s:20::13"%P,"pacientes.salud.movil + BD de formularios"]),
   ("web01",["<b>web01</b> - Caddy, Kiwix, formularios","10.20.20.15 | %s:20::15"%P,"biblioteca / registro.salud.movil","único host de la VLAN 20 abierto a invitados"]),
   ("mon01",["<b>mon01</b> - Prometheus, Grafana, rsyslog","10.20.20.14 | %s:20::14"%P,"monitoreo.salud.movil (rol en la VM ops01)"])]),
 ("v30","VLAN 30 - Clínica/Admin","#E6F4EA","#2E7D32","10.20.30.0/24","DHCPv4 + SLAAC + DHCPv6 stateless",[
   ("clin",["<b>Estaciones personal de salud</b>","DHCP 10.20.30.100-199","cable + SSID SaludMovil-Clinica"]),
   ("clinsvc",["<b>Acceso permitido</b>","pacientes, archivos, registro (consulta)","DNS/NTP en infra01, login AD"])]),
 ("v40","VLAN 40 - Comunidad/Invitados","#FEF7E0","#EF6C00","10.20.40.0/24","DHCPv4 + SLAAC con RDNSS",[
   ("guest",["<b>Visitantes y sala de espera</b>","DHCP 10.20.40.100-250","SSID SaludMovil-Comunidad (abierta)"]),
   ("portal",["<b>Portal cautivo (fw01)</b>","portal.salud.movil - 10.20.40.1","aceptar condiciones antes de salir"]),
   ("gpol",["<b>Política</b>","solo web01 (80/443) + DNS/NTP","Internet solo IPv4 tras el portal","sin acceso a VLAN 10, 30 ni al resto de la 20"])]),
]
X0,GAP,CY,CH=60,40,700,910
CW=(1960-GAP*(len(vlans)-1))//len(vlans)
HW,HH,SP=380,90,30
for i,(vid,title,fill,stroke,v4,asig,hosts) in enumerate(vlans):
    cx=X0+i*(CW+GAP)
    container(vid,"rectangleContainer",cx,CY,CW,CH,title,fill,stroke)
    n=vid[1:]; hx=cx+(CW-HW)//2
    box(vid+"_info",hx,CY+40,HW,110,["<b>%s</b>"%title.split(" - ")[1],v4,"%s:%s::/64"%(P,n),asig],fill="#FFFFFF",stroke=stroke,dash="dashed")
    y=CY+40+110+SP
    for hid,txt in hosts:
        # web01 se resalta con el color de invitados: es la excepción de F-07
        box(hid,hx,y,HW,HH,txt,fill="#FEF7E0" if hid=="web01" else "#FFFFFF",stroke="#EF6C00" if hid=="web01" else stroke); y+=HH+SP
    vlans[i]=(vid,cx)

box("cloud",910,20,260,110,["<b>Internet</b>","red de la universidad"],fill="#ECEFF1",stroke="#607D8B",typ="cloud",size=13)
box("rb",915,190,250,90,["<b>MikroTik RB3011</b>","uplink del sitio (fuera del kit)","192.168.88.0/24"],fill="#ECEFF1",stroke="#607D8B")
box("fw01",850,390,380,140,["<b>fw01 - OPNsense (VM en kvm01)</b>","WAN: VLAN 900, DHCP del RB3011","gateway .1 / ::1 en cada VLAN","Kea DHCPv4, RA/DHCPv6, portal cautivo","NAT44 + filtro IPv4/IPv6 (default deny)"],fill="#FFF3E0",stroke="#E65100")
box("note_l",80,390,560,140,["<b>Router-on-a-stick</b>","kvm01 -- trunk 802.1Q --> sw01","VLANs 10,20,30,40 + 900 (WAN); nativa 999 (parking)","kvm02/kvm03: trunk solo con VLAN 10 y 20"],fill="#FFFFFF",stroke="#9E9E9E",dash="dashed")
box("note_r",1440,390,560,140,["<b>IPv6</b>: ULA %s::/48 (RFC 4193)"%P,"un /64 por VLAN (subred = ID de VLAN)","GUA opcional por DHCPv6-PD si el uplink la entrega","reglas de firewall equivalentes en v4 y v6"],fill="#FFFFFF",stroke="#9E9E9E",dash="dashed")

line("l_inet","cloud","rb",(0.5,1),(0.5,0))
line("l_wan","rb","fw01",(0.5,1),(0.5,0),label="WAN - VLAN 900",lpos=0.4,width=3)
box("bus",60,580,1960,40,["<b>sw01 - trunk 802.1Q</b> (VLAN 10, 20, 30, 40 etiquetadas; 900 WAN; nativa 999)"],fill="#EEEEEE",stroke="#424242")
line("l_bus","fw01","bus",(0.5,1),(0.5,0),width=3)
for vid,cx in vlans:
    line("l_"+vid,"bus",vid,((cx+0.85*CW-60)/1960,1),(0.85,0),width=3,color="#424242")
save("diagrama-logico.lucid.json","Diagrama lógico")

# ---------------- Diagrama físico ----------------
container("kit","roundedRectangleContainer",20,320,1560,680,"KIT MÓVIL - vista física","#FAFAFA","#2E7D32",3)
box("cloud",670,20,260,100,["<b>Internet</b>","red de la universidad"],fill="#ECEFF1",stroke="#607D8B",typ="cloud",size=13)
box("rb",675,170,250,90,["<b>MikroTik RB3011</b>","uplink del sitio (fuera del kit)","192.168.88.0/24"],fill="#ECEFF1",stroke="#607D8B")
box("ups",60,390,340,160,["<b>UPS (lógica)</b> - sin equipo físico","NUT dummy-ups en kvm01 simula OB/LB","referencia 1000 VA/600 W: 60-90 min","carga típica ≈ 70 W, pico ≈ 135 W","alimenta kvm01, sw01 y el PoE de ap01","las laptops usan su propia batería"],fill="#FFFDE7",stroke="#F9A825",dash="dashed")
box("sw01",460,420,680,100,["<b>sw01</b> - Cisco SG350X-24","gestión 10.20.10.2 (VLAN 10)","puertos sin uso: shutdown, VLAN 999"],fill="#EEEEEE",stroke="#424242")
box("legend",1200,420,340,100,["<b>Convenciones</b>","línea continua: cable Ethernet","línea punteada: energía, Wi-Fi u opcional"],fill="#FFFFFF",stroke="#9E9E9E",dash="dashed")
box("kvm01",60,660,340,150,["<b>kvm01</b> - nodo principal","mini PC (laptop en el perfil 3)","fw01 + infra01 siempre; resto según perfil","gestión 10.20.10.5","SSD: SO + VMs","disco USB de backups en el nodo de ops01"],fill="#E8F0FE",stroke="#1565C0")
box("kvm0x",440,660,240,150,["<b>kvm02 / kvm03</b>","nodos opcionales","laptops del grupo","gestión 10.20.10.6 / .7","perfiles 2 y 3"],fill="#E8F0FE",stroke="#1565C0",dash="dashed")
box("gest",720,660,200,150,["<b>Estaciones</b>","<b>de gestión</b>","personal técnico","VLAN 10 (solo cable)"],fill="#FDECEA",stroke="#C62828")
box("clin",960,660,200,150,["<b>Estaciones</b>","<b>clínicas</b>","personal de salud","VLAN 30"],fill="#E6F4EA",stroke="#2E7D32")
box("ap01",1200,660,340,150,["<b>ap01</b> - AP multi-SSID (Wi-Fi 5/6)","gestión 10.20.10.3 (VLAN 10 nativa)","SaludMovil-Clinica → VLAN 30","SaludMovil-Comunidad → VLAN 40"],fill="#FEF7E0",stroke="#EF6C00")
box("wclin",1200,870,160,110,["<b>Personal</b>","<b>de salud</b>","WPA3/WPA2"],fill="#E6F4EA",stroke="#2E7D32")
box("wcom",1380,870,160,110,["<b>Comunidad</b>","dispositivos propios","portal cautivo"],fill="#FEF7E0",stroke="#EF6C00")

line("p_inet","cloud","rb",(0.5,1),(0.5,0))
line("p_wan","rb","sw01",(0.5,1),(0.5,0),label="gi1/0/3 - acceso VLAN 900 (WAN)",width=3)
line("p_kvm","sw01","kvm01",(0.03,1),(0.5,0),label="gi1/0/1 - trunk (todas)",lpos=0.3,width=3)
line("p_kvm0x","sw01","kvm0x",(0.15,1),(0.5,0),label="gi1/0/4-5 - trunk (10, 20)",lpos=0.55,width=3,dash="dashed")
line("p_gest","sw01","gest",(0.53,1),(0.5,0),label="gi1/0/10-11 - VLAN 10",lpos=0.55)
line("p_clin","sw01","clin",(0.82,1),(0.5,0),label="gi1/0/6-9 - VLAN 30",lpos=0.55)
line("p_ap","sw01","ap01",(0.99,1),(0.5,0),label="gi1/0/2 - trunk",lpos=0.55,width=3)
line("p_ups_sw","ups","sw01",(1,0.5),(0,0.5),dash="dashed",color="#F9A825")
line("p_ups_kvm","ups","kvm01",(0.5,1),(0.5,0),label="energía + USB (NUT)",lpos=0.6,dash="dashed",color="#F9A825")
line("p_w1","ap01","wclin",(0.24,1),(0.5,0),label="SSID Clinica",dash="dashed",color="#EF6C00")
line("p_w2","ap01","wcom",(0.76,1),(0.5,0),label="SSID Comunidad",dash="dashed",color="#EF6C00")
save("diagrama-fisico.lucid.json","Diagrama físico")
