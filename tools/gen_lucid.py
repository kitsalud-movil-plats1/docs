import json
P="fd5a:fc7e:d716"
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

# Kit container first (z-order back)
KX,KY,KW,KH=20,330,2060,1240
shapes.append({"id":"kit","type":"roundedRectangleContainer","boundingBox":{"x":KX,"y":KY,"w":KW,"h":KH},
  "containerTitle":{"text":"KIT MÓVIL - MinisForum Venus (kvm01) + switch SG350X + AP multi-SSID (UPS lógica)"},
  "style":{"fill":{"type":"color","color":"#FAFAFA"},"stroke":{"color":"#2E7D32","width":3,"style":"solid"}}})

vlans=[
 ("v10","VLAN 10 - Gestión","#FDECEA","#C62828","10.20.10.0/24","Estático + reservas DHCP",[
   ("sw01",["<b>sw01</b> - Cisco SG350X-24","10.20.10.2 | %s:10::2"%P,"trunk 802.1Q hacia kvm01 / ap01"]),
   ("ap01",["<b>ap01</b> - AP multi-SSID","10.20.10.3 | %s:10::3"%P,"SSID Gestión/Clínica/Comunidad"]),
   ("kvm01",["<b>kvm01</b> - Ubuntu 24.04 + KVM","10.20.10.5 | %s:10::5"%P,"hipervisor, restic, NUT (UPS simulada)"]),
   ("adm",["<b>Equipos del personal técnico</b>","reservas 10.20.10.100-119","SSH/HTTPS de gestión solo desde aquí"])]),
 ("v20","VLAN 20 - Servidores","#E8F0FE","#1565C0","10.20.20.0/24","Estático (IPv6 espejo de IPv4)",[
   ("infra01",["<b>infra01</b> - BIND9 + Chrony","10.20.20.10 | %s:20::10"%P,"ns1 / ntp.salud.movil"]),
   ("dc01",["<b>dc01</b> - Samba AD DC","10.20.20.11 | %s:20::11"%P,"dominio ad.salud.movil"]),
   ("files01",["<b>files01</b> - Samba SMB + NFS","10.20.20.12 | %s:20::12"%P,"archivos.salud.movil"]),
   ("apps01",["<b>apps01</b> - DHIS2 + PostgreSQL","10.20.20.13 | %s:20::13"%P,"pacientes.salud.movil"]),
   ("mon01",["<b>mon01</b> - Prometheus/Grafana/Loki","10.20.20.14 | %s:20::14"%P,"monitoreo.salud.movil"])]),
 ("v30","VLAN 30 - Clínica/Admin","#E6F4EA","#2E7D32","10.20.30.0/24","DHCPv4 + SLAAC + DHCPv6 stateless",[
   ("clin",["<b>Estaciones personal de salud</b>","DHCP 10.20.30.100-199","cable + SSID SaludMovil-Clinica"]),
   ("clinsvc",["<b>Acceso permitido</b>","pacientes, archivos, registro (admin)","DNS/NTP en infra01, login AD"])]),
 ("v40","VLAN 40 - Comunidad/Invitados","#FEF7E0","#EF6C00","10.20.40.0/24","DHCPv4 + SLAAC con RDNSS",[
   ("guest",["<b>Visitantes y sala de espera</b>","DHCP 10.20.40.100-250","SSID SaludMovil-Comunidad (abierta)"]),
   ("portal",["<b>Portal cautivo (fw01)</b>","portal.salud.movil - 10.20.40.1","aceptar condiciones antes de salir"]),
   ("gpol",["<b>Política</b>","solo DMZ + DNS/NTP; Internet solo v4","sin acceso a VLAN 10/20/30"])]),
 ("v50","VLAN 50 - DMZ pública","#F3E8FD","#6A1B9A","10.20.50.0/24","Estático",[
   ("dmz01",["<b>dmz01</b> - Caddy (reverse proxy)","10.20.50.10 | %s:50::10"%P,"Docker Compose"]),
   ("kiwix",["<b>Kiwix-serve</b> (en dmz01)","biblioteca.salud.movil","ZIM de salud via NFS (ro)"]),
   ("forms",["<b>App de formularios</b> (en dmz01)","registro.salud.movil","datos en PostgreSQL de apps01"])]),
]
CW,GAP,X0,CY=360,40,60,700
HW,HH=280,90
for i,(vid,title,fill,stroke,v4,asig,hosts) in enumerate(vlans):
    cx=X0+i*(CW+GAP)
    shapes.append({"id":vid,"type":"rectangleContainer","boundingBox":{"x":cx,"y":CY,"w":CW,"h":840},
      "containerTitle":{"text":title},
      "style":{"fill":{"type":"color","color":fill},"stroke":{"color":stroke,"width":2,"style":"solid"}}})
    n=vid[1:]
    box(vid+"_info",cx+40,CY+40,HW,110,["<b>%s</b>"%title.split(" - ")[1],v4,"%s:%s::/64"%(P,n),asig],fill="#FFFFFF",stroke=stroke,dash="dashed")
    y=CY+40+110+40
    for hid,txt in hosts:
        box(hid,cx+40,y,HW,HH,txt,stroke=stroke); y+=HH+40
    vlans[i]=vid

box("cloud",910,20,260,110,["<b>Internet</b>","red de la universidad"],fill="#ECEFF1",stroke="#607D8B",typ="cloud",size=13)
box("rb",915,190,250,90,["<b>MikroTik RB3011</b>","uplink del sitio (fuera del kit)","192.168.88.0/24"],fill="#ECEFF1",stroke="#607D8B")
box("fw01",850,390,380,140,["<b>fw01 - OPNsense (VM en kvm01)</b>","WAN: VLAN 900, DHCP del RB3011","gateway .1 / ::1 en cada VLAN","Kea DHCPv4, RA/DHCPv6, portal cautivo","NAT44 + filtro IPv4/IPv6 (default deny)"],fill="#FFF3E0",stroke="#E65100")
box("note_l",80,390,560,140,["<b>Router-on-a-stick</b>","kvm01 -- trunk 802.1Q --> sw01","VLANs 10,20,30,40,50 + 900 (WAN); nativa 999 (parking)","las VMs se conectan a bridges por VLAN en kvm01"],fill="#FFFFFF",stroke="#9E9E9E",dash="dashed")
box("note_r",1440,390,560,140,["<b>IPv6</b>: ULA %s::/48 (RFC 4193)"%P,"un /64 por VLAN (subred = ID de VLAN)","GUA opcional por DHCPv6-PD si el uplink la entrega","reglas de firewall equivalentes en v4 y v6"],fill="#FFFFFF",stroke="#9E9E9E",dash="dashed")

line("l_inet","cloud","rb",(0.5,1),(0.5,0))
line("l_wan","rb","fw01",(0.5,1),(0.5,0),label="WAN - VLAN 900",lpos=0.4,width=3)
box("bus",60,580,1960,40,["<b>sw01 - trunk 802.1Q</b> (VLAN 10, 20, 30, 40, 50 etiquetadas; 900 WAN; nativa 999)"],fill="#EEEEEE",stroke="#424242")
line("l_bus","fw01","bus",(0.5,1),(0.5,0),width=3)
for i,v in enumerate(vlans):
    line("l_"+v,"bus",v,((60+i*400+306-60)/1960,1),(0.85,0),width=3,color="#424242")
# logical service dependencies (dashed)
line("d_forms_db","forms","apps01",(0,0.5),(1,0.5),dash="dashed",color="#6A1B9A") if False else None
doc={"version":1,"pages":[{"id":"p1","title":"Diagrama lógico","shapes":shapes,"lines":lines}]}
open(__import__('os').path.join(__import__('os').path.dirname(__file__),'..','diagramas','diagrama-logico.lucid.json'),'w').write(json.dumps(doc,ensure_ascii=False,separators=(",",":")))
print(len(json.dumps(doc)))
