
Dev-TODO
--------

Board Generation
* Create proper board generation. Candidate design: input for the generator is a generic row specification i.e. how many tasks of a certain difficulty / how many restriction tasks. Generate board such that each row and column follows this spec. To start, use a fixed coloring of 5x5 board. This would require classification of tasks into difficulty / attributes (e.g. restriction task). 
0 1 2 3 4
2 0 3 4 1
3 4 1 0 2
4 2 0 1 3
1 3 4 2 0
* Might generate difficulty of production tasks automatically, but for this the game object needs to be available for access to prototypes, i.e. can only be done on init or later, so would need to make sure nothing uses difficulty properties before init.


Tasks
* More Tasks. 
* More Task Types
    - Build restriction tasks e.g. build at most one offshore pump. Enforced by mod, with checkbox to remove enforcement and mark task as failed, enabled by default. Should allow multiple restrictions in one task. In particular: Do not build any of type x. 
    - Time limit tasks. "Research steel axe before 25 minutes"
    - Consider a model for subtasks / composite tasks. Ideally this would make tasks like "produce 5k iron plates before 20 minutes" or "build at most one type of inserter" easier, but needs to be well designed, maybe easier to code by hand in the few cases we want
* May need a better interface between board and tasks. Cannot currently reset tasks (e.g. to roll back erroneous completion of task)


UI
* Use custom styles instead of setting style properties by hand in places where it makes sense.
* Make everything prettier


Game Rules / Setup
* Find a convenient way to enter settings such as board generation settings or recipe / technology state. Options appear to be mod settings or ingame menu. Issue with mod settings: difficult to transfer. Work with presets?


Control
* Chat cmds. for resetting / disabling tasks, rolling back a victory (need to make changes to Board / Task interface) and to start board for a player.

Meta
* Move this to git issues