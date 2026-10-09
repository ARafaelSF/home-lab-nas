import re
import unittest
import importlib.util
import uuid
from pathlib import Path

ROOT = Path(__file__).parents[3]
ROUTINE = ROOT / "scripts/proxmox-reserva/rotina-semanal.sh"
LISTENER = ROOT / "scripts/container-ops/ha-update-listener.py"


def load_listener_module():
    spec = importlib.util.spec_from_file_location("ha_update_listener_test", LISTENER)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class ShutdownProtocolTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.routine = ROUTINE.read_text(encoding="utf-8")
        cls.listener = LISTENER.read_text(encoding="utf-8")

    def test_shutdown_only_keeps_notifications_enabled(self):
        self.assertNotIn("--shutdown-only).*NOTIFY_HA=0", self.routine)

    def test_preflight_checks_tasks_vms_processes_and_locks(self):
        for marker in ("pvesh", "qm list", "pgrep", "qm config", "critical_task_active", "vm_not_stopped"):
            self.assertIn(marker, self.routine)

    def test_states_are_explicit(self):
        for marker in ("status=shutdown_requested", '"failed"', '"unknown"'):
            self.assertIn(marker, self.routine)
        self.assertIn("shutdown_unreachable_first", self.routine)
        self.assertIn("shutdown_unreachable_stable", self.routine)
        self.assertIn("sleep 120", self.routine)

    def test_no_forced_stop_or_skiplock_in_shutdown_changes(self):
        self.assertNotIn("qm stop --skiplock", self.routine)
        self.assertNotIn("shutdown -f", self.routine)

    def test_listener_generates_request_id_and_returns_it(self):
        self.assertIn("uuid.uuid4()", self.listener)
        self.assertIn('"request_id": request_id', self.listener)
        self.assertIn('env["SHUTDOWN_REQUEST_ID"] = request_id', self.listener)
        self.assertIn('threading.Thread(target=run_reserva, args=(request_id,), daemon=True)', self.listener)
        self.assertIn('"action": "proxmox-reserva", "request_id": request_id', self.listener)

    def test_listener_distinguishes_acceptance_from_completion(self):
        self.assertIn('"accepted": True', self.listener)
        self.assertIn("terminou code=", self.listener)

    def test_no_power_cut_command_added(self):
        self.assertNotIn("switch.turn_off", self.routine)

    def test_event_schema_is_documented_in_code(self):
        self.assertIn("request_id=$request_id", self.routine)
        self.assertIn('"status": status', self.routine)
        self.assertIn('"observed_at": observed', self.routine)

    def test_shutdown_only_allows_stopped_vm_with_historical_lock(self):
        shutdown_section = self.routine.split("validate_shutdown_preflight()", 1)[1]
        shutdown_section = shutdown_section.split("shutdown_reserva()", 1)[0]
        self.assertNotIn("lock_present_", shutdown_section)
        self.assertIn("historical lock", self.routine)

    def test_reappearance_is_unknown_and_does_not_authorize_cut(self):
        stable_section = self.routine.split("shutdown_unreachable_first", 1)[1]
        self.assertIn('"unknown"', stable_section)
        self.assertIn("host voltou a responder", stable_section)
        self.assertIn("corte não autorizado", stable_section)

    def test_request_id_is_carried_in_every_event(self):
        self.assertIn('"request_id": request_id', self.routine)

    def test_listener_rejects_concurrent_shutdown_requests(self):
        self.assertIn("if _reserva_shutdown_pending or _reserva_pending:", self.listener)
        self.assertIn('"error": "busy"', self.listener)
        self.assertIn('"reserva_shutdown_pending": _reserva_shutdown_pending', self.listener)

    def test_preflight_uses_endtime_and_qm_status_without_json_qm_list(self):
        self.assertIn('task.get("endtime")', self.routine)
        self.assertIn('["qm", "status", str(vmid)]', self.routine)
        self.assertNotIn('["qm", "list", "--output-format", "json"]', self.routine)

    def test_preflight_logs_blocking_task_identity(self):
        self.assertIn('"type": task.get("type")', self.routine)
        self.assertIn('"upid": task.get("upid")', self.routine)
        self.assertIn('"status": status or "unknown"', self.routine)

    def test_process_check_avoids_self_matching_pgrep(self):
        self.assertIn('subprocess.run(["pgrep", "-x", proc]', self.routine)

    def test_supplied_uuid_is_reused_without_changes(self):
        module = load_listener_module()
        request_id = str(uuid.uuid4())
        self.assertEqual(module.resolve_shutdown_request_id({"request_id": request_id}), request_id)

    def test_missing_uuid_keeps_backward_compatible_generation(self):
        module = load_listener_module()
        request_id = module.resolve_shutdown_request_id({})
        self.assertEqual(str(uuid.UUID(request_id)), request_id)

    def test_invalid_uuid_is_rejected_before_start(self):
        module = load_listener_module()
        for value in ("", "not-a-uuid", "  not-a-uuid"):
            with self.assertRaises(ValueError):
                module.resolve_shutdown_request_id({"request_id": value})


if __name__ == "__main__":
    unittest.main()
