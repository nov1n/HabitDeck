build-zip: ## generate ./Spoons/HabitDeck.spoon.zip
	cd Source && \
		zip -r ../Spoons/HabitDeck.spoon.zip HabitDeck.spoon

restart:
  killall Hammerspoon ; open -a Hammerspoon && open -a Hammerspoon
