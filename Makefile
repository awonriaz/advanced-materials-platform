.PHONY: install test run docker demo full-demo k8s fabric

install:
	python -m pip install --upgrade pip
	pip install -r requirements.txt

test:
	API_KEY=$$(python -c 'import secrets; print(secrets.token_hex(32))') python -m pytest -q

run:
	uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

docker:
	docker compose up -d --build

demo:
	bash scripts/run_demo.sh

full-demo:
	docker compose --profile full up -d --build
	bash scripts/run_level6_integrations_demo.sh

k8s:
	bash k8s/deploy-kind.sh

fabric:
	bash fabric/scripts/bootstrap_test_network.sh
	bash fabric/scripts/deploy_material_passport.sh
	bash fabric/scripts/invoke_material_demo.sh
