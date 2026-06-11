from app.iot import process_optimization, predictive_quality_summary
from app.compliance import validate_certification
from app.threat_detection import analyze_threat_signal
from app.risk import diversification_strategy


def test_process_optimization_temperature_warning():
    result = process_optimization("temperature_c", 872.5, "C")
    assert result["level"] == "WARNING"
    assert "inspection" in result["recommended_action"].lower()


def test_predictive_quality_summary():
    inspections = [{"result": "FAIL", "defect_score": 80}, {"result": "PASS", "defect_score": 10}]
    process_events = [{"optimization": {"level": "WARNING"}}]
    result = predictive_quality_summary(inspections, process_events)
    assert result["defect_rate_percent"] == 50.0
    assert result["prediction"] == "HIGH_RISK_OF_QUALITY_DRIFT"


def test_certification_validation():
    result = validate_certification("ISO9001", "CERT-001", "Demo Body", None)
    assert result["status"] == "VALIDATED"
    assert len(result["evidence_hash"]) == 64


def test_threat_signal_analysis():
    result = analyze_threat_signal("SUPPLIER_COMPROMISE", "HIGH", ["ioc-1", "ioc-2"])
    assert result["threat_score"] >= 70
    assert result["detected"] is True


def test_diversification_strategy_for_rare_earth():
    result = diversification_strategy("rare-earth", "high", True)
    assert result["criticality_weight"] >= 25
    assert len(result["recommended_diversification_actions"]) >= 3
