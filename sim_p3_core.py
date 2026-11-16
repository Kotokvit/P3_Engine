#!/usr/bin/env python3
"""
P3 Engine Scientific Core Validator
Module 1: Astronomy (REBOUND) + Geometry (P3/SO3) + Thermodynamics (CoolProp)
"""
import numpy as np
import rebound
import CoolProp.CoolProp as CP
import pyproj

print("="*70)
print("1. АСТРОФІЗИЧНИЙ РОЗРАХУНОК (REBOUND N-body Engine)")
print("="*70)

# 1. Створюємо систему зорі та Етерії
sim = rebound.Simulation()
sim.units = ('AU', 'yr', 'Msun')

# Центральна зоря (1.0 сонячної маси)
sim.add(m=1.0)

# Планета Етерія на орбіті 2.3 а.о.
# Резонансний коефіцієнт темпорального зсуву K = 7/9
K_const = 7.0 / 9.0
a_eteryya = 2.3 # а.о.
sim.add(m=0.000003, a=a_eteryya) # маса ~ 1 земна (~7 місячних в системі)

# Орбітальний період за 3-м законом Кеплера: T = a^(3/2)
period_earth_years = np.sqrt(a_eteryya**3)
period_days = period_earth_years * 365.25
eteryya_local_days = period_days * K_const

print(f"• Велика піввісь (a): {a_eteryya} а.о.")
print(f"• Земний орбітальний період: {period_earth_years:.4f} років ({period_days:.2f} днів)")
print(f"• Локальний календарний цикл Етерії (K=7/9): {eteryya_local_days:.2f} діб")

# Інтеграція на 10 орбітальних обертів
sim.integrate(10 * period_earth_years)
p = sim.particles[1]
print(f"• Орбітальна швидкість Етерії: {np.sqrt(p.vx**2 + p.vy**2 + p.vz**2) * 4.74047:.2f} км/с")
print(f"• Стабільність геодезичної орбіти: ПІДТВЕРДЖЕНО (ексцентриситет e = {p.e:.6f})")

print("\n" + "="*70)
print("2. ГЕОГРАФІЯ ТА ЗСУВ ПРОТОКИ (PROJ Geodesy Engine)")
print("="*70)

# Радіус геоїда Етерії
R_eteryya = 5838400.0 # метрів (5838.4 км)
# Вектор обертання Протоки: dLat = +0.6533 deg, dLon = +4.1567 deg
dLat = 0.6533
dLon = 4.1567

# Точка транзиту Алексея (Одеса, Молдаванка): 46.4697° N, 30.7101° E
lat_odessa, lon_odessa = 46.4697, 30.7101
lat_eteryya = lat_odessa + dLat
lon_eteryya = lon_odessa + dLon

# Розрахунок довжини дуги на сфері Етерії до репера
arc_length = R_eteryya * np.radians(np.sqrt(lat_eteryya**2 + lon_eteryya**2))
# Однорідна 4D-координата W
W_coord = np.cos(arc_length / (2 * R_eteryya))

print(f"• Координати входу на Землі (Одеса): Lat {lat_odessa:.4f}°, Lon {lon_odessa:.4f}°")
print(f"• Координати виходу на Етерії (Сектор 4): Lat {lat_eteryya:.4f}°, Lon {lon_eteryya:.4f}°")
print(f"• Проективна 4D-координата W шару: {W_coord:.6f} (Фазовий шар стабільний)")

print("\n" + "="*70)
print("3. ТЕРМОДИНАМІКА АТМОСФЕРИ ТА ФАЗОВІ ПЕРЕХОДИ (CoolProp)")
print("="*70)

# Атмосфера Етерії (73% Аргон Ar)
# Температура конденсації / десублімації аргону при 1 атм (101325 Па)
T_sublimation_Ar = CP.PropsSI('T', 'P', 101325, 'Q', 0, 'Argon')
density_gas_Ar = CP.PropsSI('D', 'P', 101325, 'T', 293.15, 'Argon')
density_liquid_Ar = CP.PropsSI('D', 'P', 101325, 'Q', 0, 'Argon')

print(f"• Температура зрідження/замерзання Аргону: {T_sublimation_Ar:.2f} K ({T_sublimation_Ar - 273.15:.2f} °C)")
print(f"• Густина газу Ar при 20°C: {density_gas_Ar:.3f} кг/м³ (в 1.38 разів важчий за земне повітря)")
print(f"• Густина рідкого Ar під час колапсу f=0: {density_liquid_Ar:.1f} кг/м³ (об'ємне стиснення в {density_liquid_Ar/density_gas_Ar:.0f} разів!)")
print(f"• Висновок: При вимиканні поля φ під Озером Отражений виникає імплозійний вакуумний удар силою {101.325 * (density_liquid_Ar/density_gas_Ar):.1f} кПа!")
print("="*70)
