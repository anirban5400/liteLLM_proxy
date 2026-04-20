.PHONY: start stop restart status remove remove-all logs start-prod stop-prod restart-prod status-prod remove-prod remove-all-prod logs-prod

start:
	@./scripts/litellm start

stop:
	@./scripts/litellm stop

restart:
	@./scripts/litellm restart

status:
	@./scripts/litellm status

remove:
	@./scripts/litellm remove

remove-all:
	@./scripts/litellm remove-all

logs:
	@./scripts/litellm logs

start-prod:
	@./scripts/litellm start-prod

stop-prod:
	@./scripts/litellm stop-prod

restart-prod:
	@./scripts/litellm restart-prod

status-prod:
	@./scripts/litellm status-prod

remove-prod:
	@./scripts/litellm remove-prod

remove-all-prod:
	@./scripts/litellm remove-all-prod

logs-prod:
	@./scripts/litellm logs-prod
