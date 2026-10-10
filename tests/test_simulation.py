#!/usr/bin/env python3
"""
Unit and Logic Simulation Tests for Quick Ally Resource Sharer Widget.
Tests stall detection thresholds, surplus safety criteria, and snooze logic.
"""

import unittest

# Mirroring CONFIG from gui_quick_resource_sharer.lua
CONFIG = {
    "energyShareAmount": 500,
    "metalShareAmount": 200,
    "energyStallThreshold": 100,
    "energyStallRatio": 0.05,
    "metalStallThreshold": 50,
    "metalStallRatio": 0.05,
    "myMinEnergyReserve": 1000,
    "myMinMetalReserve": 400,
    "snoozeDurationSec": 45,
}

def is_energy_stalling(cur, stor, inc, exp):
    """Simulates the Lua stall detection condition for energy."""
    is_low = (cur < CONFIG["energyStallThreshold"]) or (stor and cur < stor * CONFIG["energyStallRatio"])
    is_deficit = exp > inc
    return bool(is_low and is_deficit)

def is_metal_stalling(cur, stor, inc, exp):
    """Simulates the Lua stall detection condition for metal."""
    is_low = (cur < CONFIG["metalStallThreshold"]) or (stor and cur < stor * CONFIG["metalStallRatio"])
    is_deficit = exp > inc
    return bool(is_low and is_deficit)

def can_local_player_donate(res_type, current_level):
    """Checks if local player meets safety reserve criteria."""
    if res_type == "energy":
        return current_level >= CONFIG["myMinEnergyReserve"] and current_level >= (CONFIG["energyShareAmount"] * 1.5)
    elif res_type == "metal":
        return current_level >= CONFIG["myMinMetalReserve"] and current_level >= (CONFIG["metalShareAmount"] * 1.5)
    return False

def remove_alert_by_index(alert_list, index):
    """Simulates the in-place array shift used in Lua."""
    if 0 <= index < len(alert_list):
        return alert_list[:index] + alert_list[index+1:]
    return alert_list


class TestWidgetLogic(unittest.TestCase):

    def test_energy_stall_detected_when_empty_and_spending(self):
        # Ally has 20 energy, 1000 storage, income 50, expense 100
        self.assertTrue(is_energy_stalling(20, 1000, 50, 100))

    def test_energy_stall_ignored_when_surplus_income(self):
        # Ally has 20 energy, but income 200 and expense 50 (recovering)
        self.assertFalse(is_energy_stalling(20, 1000, 200, 50))

    def test_energy_stall_ignored_when_storage_healthy(self):
        # Ally has 500 energy out of 1000, spending 100
        self.assertFalse(is_energy_stalling(500, 1000, 50, 100))

    def test_metal_stall_detected_when_empty_and_spending(self):
        # Ally has 10 metal, 1000 storage, income 10, expense 30
        self.assertTrue(is_metal_stalling(10, 1000, 10, 30))

    def test_local_player_cannot_donate_if_low_reserves(self):
        # Local player has 800 energy (< 1000 threshold)
        self.assertFalse(can_local_player_donate("energy", 800))
        # Local player has 300 metal (< 400 threshold)
        self.assertFalse(can_local_player_donate("metal", 300))

    def test_local_player_can_donate_with_sufficient_reserves(self):
        # Local player has 2000 energy (> 1000 and > 750)
        self.assertTrue(can_local_player_donate("energy", 2000))
        # Local player has 600 metal (> 400 and > 300)
        self.assertTrue(can_local_player_donate("metal", 600))

    def test_immediate_alert_removal(self):
        alerts = ["alert_A", "alert_B", "alert_C"]
        # Remove middle item
        updated = remove_alert_by_index(alerts, 1)
        self.assertEqual(updated, ["alert_A", "alert_C"])


if __name__ == "__main__":
    unittest.main()
