using Godot;

public partial class QuestManager : Node
{
	public static QuestManager Instance { get; private set; }

	public override void _Ready()
	{
		Instance = this;
		GD.Print("QuestManager ready.");
	}

	public override void _ExitTree()
	{
		if (Instance == this)
		{
			Instance = null;
		}
	}
}
