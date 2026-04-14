# rpcenum

Script de enumeración RPC para entornos Active Directory vía `rpcclient`.

> **Créditos originales:** [Marcelo Vázquez (S4vitar)](https://github.com/s4vitar)  
> Este repositorio contiene una versión actualizada y modificada del script original.

---

## ¿Qué hace?

Automatiza la enumeración de un dominio Windows a través del protocolo RPC (puerto 139), permitiendo extraer:

- **DUsers** — Usuarios del dominio
- **DUsersInfo** — Usuarios del dominio con descripción
- **DAUsers** — Usuarios del grupo Domain Admins
- **DGroups** — Grupos del dominio
- **All** — Todos los modos anteriores en secuencia

---

## Cambios respecto al original

- Soporte de **autenticación con credenciales** (usuario y contraseña), además de null session
- **Modo interactivo**: si no se pasan flags, el script solicita los datos paso a paso
- Nuevas flags `-u` (usuario) y `-p` (contraseña)
- Wrapper `rpcclient_cmd()` centralizado para manejar null session vs. sesión autenticada
- Limpieza de archivos temporales mejorada con `rm -f`
- `trap ctrl_c INT` movido al scope global
- Mensajes de error más descriptivos en caso de acceso denegado

---

## Instalación

```bash
chmod +x rpcenum.sh
sudo cp rpcenum.sh /usr/local/bin/rpcenum
```

---

## Uso

### Modo interactivo (sin flags)
```bash
sudo rpcenum
```
El script te pedirá la IP, usuario, contraseña y modo de enumeración.

### Modo con flags

```bash
# Null session
sudo rpcenum -i 192.168.1.10 -e All

# Con credenciales
sudo rpcenum -i 192.168.1.10 -e All -u Administrator -p 'P@ssw0rd'

# Ver ayuda
sudo rpcenum -h
```

### Flags disponibles

| Flag | Descripción |
|------|-------------|
| `-i` | IP del objetivo |
| `-e` | Modo de enumeración (`DUsers`, `DUsersInfo`, `DAUsers`, `DGroups`, `All`) |
| `-u` | Usuario (opcional, default: null session) |
| `-p` | Contraseña (opcional) |
| `-h` | Panel de ayuda |

---

## Requisitos

- Kali Linux (o cualquier distro con `rpcclient` y `nmap`)
- Ejecutar como **root**
- Puerto **139** abierto en el objetivo

---

## Disclaimer

Este script es para uso en entornos controlados y con autorización explícita.  
El uso no autorizado contra sistemas ajenos es ilegal.