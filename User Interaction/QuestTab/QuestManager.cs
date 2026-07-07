using Godot;
using System;
using System.Linq;
using System.Collections.Generic;

public partial class QuestManager : Node
{
	public static QuestManager Instance { get; private set; }

	[Signal] public delegate void QuestStartedEventHandler(string questId);
	[Signal] public delegate void QuestUpdatedEventHandler(string questId);
	[Signal] public delegate void QuestCompletedEventHandler(string questId);
	[Signal] public delegate void QuestListChangedEventHandler();

	private readonly Dictionary<string, QuestDefinition> _definitions = new();
	private readonly Dictionary<string, QuestInstance> _activeQuests = new();
	private readonly HashSet<string> _completedQuests = new();

	public override void _Ready()
	{
		Instance = this;
		LoadQuestDefinitions();
		GD.Print("QuestManager ready.");
	}

	public override void _ExitTree()
	{
		if (Instance == this)
			Instance = null;
	}

	public void StartQuest(string questId)
	{
		if (_activeQuests.ContainsKey(questId) || _completedQuests.Contains(questId))
			return;

		if (!_definitions.TryGetValue(questId, out QuestDefinition definition))
		{
			GD.PushWarning($"Quest definition not found: {questId}");
			return;
		}

		QuestInstance instance = QuestInstance.FromDefinition(definition);
		instance.Status = QuestStatus.Active;
		_activeQuests[questId] = instance;

		EmitSignal(SignalName.QuestStarted, questId);
		EmitSignal(SignalName.QuestListChanged);
	}

	public void ReportEvent(string eventType, string targetId = "", int amount = 1)
	{
		QuestEvent questEvent = new(eventType, targetId, amount);
		List<string> completedNow = new();

		foreach (QuestInstance quest in _activeQuests.Values)
		{
			if (quest.Status != QuestStatus.Active)
				continue;

			bool changed = quest.HandleEvent(questEvent);

			if (changed)
				EmitSignal(SignalName.QuestUpdated, quest.Id);

			if (quest.IsCompleted)
				completedNow.Add(quest.Id);
		}

		foreach (string questId in completedNow)
			CompleteQuest(questId);
	}

	public void CompleteQuest(string questId)
	{
		if (!_activeQuests.TryGetValue(questId, out QuestInstance quest))
			return;

		quest.Status = QuestStatus.Completed;
		_activeQuests.Remove(questId);
		_completedQuests.Add(questId);

		EmitSignal(SignalName.QuestCompleted, questId);
		EmitSignal(SignalName.QuestListChanged);
	}

	public bool IsQuestActive(string questId)
	{
		return _activeQuests.ContainsKey(questId);
	}

	public bool IsQuestCompleted(string questId)
	{
		return _completedQuests.Contains(questId);
	}

	public Godot.Collections.Array<Godot.Collections.Dictionary> GetActiveQuestViewData()
	{
		Godot.Collections.Array<Godot.Collections.Dictionary> result = new();

		foreach (QuestInstance quest in _activeQuests.Values)
			result.Add(quest.ToViewData());

		return result;
	}

	private void LoadQuestDefinitions()
	{
		QuestDefinition cleanTrash = new(
		id: "clean_trash_01",
		title: "Bersihkan Sampah",
		description: "Bersihkanlah Tumpukan-tumpukan sampah yang kamu temukan disekitar hutan.",
		objectives: new List<ObjectiveDefinition>
		{
			new("clean_trash", "PileTrash", 5, "Clean 5 Pile of Trash")
		}
	);
		
		QuestDefinition talkToNPC = new(
			id: "talk_to_Dzakwan",
			title: "Bicaralah dengan Dzakwan",
			description: "Temui Penduduk disekitar sini dan tanyai apa yang terjadi dengan hutan.",
			objectives: new List<ObjectiveDefinition>
	{
		new("talk_npc", "NPC_01", 1, "Temui Dzakwan")
	}
);

		_definitions[talkToNPC.Id] = talkToNPC;
		_definitions[cleanTrash.Id] = cleanTrash;
	}
}

public enum QuestStatus
{
	Locked,
	Available,
	Active,
	Completed,
	Failed,
	TurnedIn
}

public sealed class QuestEvent
{
	public string Type { get; }
	public string TargetId { get; }
	public int Amount { get; }

	public QuestEvent(string type, string targetId, int amount)
	{
		Type = type;
		TargetId = targetId;
		Amount = Math.Max(1, amount);
	}
}

public sealed class QuestDefinition
{
	public string Id { get; }
	public string Title { get; }
	public string Description { get; }
	public IReadOnlyList<ObjectiveDefinition> Objectives { get; }

	public QuestDefinition(string id, string title, string description, IReadOnlyList<ObjectiveDefinition> objectives)
	{
		Id = id;
		Title = title;
		Description = description;
		Objectives = objectives;
	}
}

public sealed class ObjectiveDefinition
{
	public string Type { get; }
	public string TargetId { get; }
	public int RequiredAmount { get; }
	public string Description { get; }

	public ObjectiveDefinition(string type, string targetId, int requiredAmount, string description)
	{
		Type = type;
		TargetId = targetId;
		RequiredAmount = Math.Max(1, requiredAmount);
		Description = description;
	}
}

public sealed class QuestInstance
{
	public string Id => Definition.Id;
	public QuestDefinition Definition { get; }
	public QuestStatus Status { get; set; }
	public List<IQuestObjective> Objectives { get; }
	public bool IsCompleted => Objectives.All(objective => objective.IsCompleted);

	private QuestInstance(QuestDefinition definition, List<IQuestObjective> objectives)
	{
		Definition = definition;
		Objectives = objectives;
		Status = QuestStatus.Available;
	}

	public static QuestInstance FromDefinition(QuestDefinition definition)
	{
		List<IQuestObjective> objectives = definition.Objectives
			.Select(ObjectiveFactory.Create)
			.ToList();

		return new QuestInstance(definition, objectives);
	}

	public bool HandleEvent(QuestEvent questEvent)
	{
		bool changed = false;

		foreach (IQuestObjective objective in Objectives)
		{
			if (objective.IsCompleted)
				continue;

			changed |= objective.HandleEvent(questEvent);
		}

		return changed;
	}

	public Godot.Collections.Dictionary ToViewData()
	{
		Godot.Collections.Array<Godot.Collections.Dictionary> objectiveData = new();

		foreach (IQuestObjective objective in Objectives)
			objectiveData.Add(objective.ToViewData());

		return new Godot.Collections.Dictionary
		{
			{ "id", Id },
			{ "title", Definition.Title },
			{ "description", Definition.Description },
			{ "status", Status.ToString() },
			{ "is_completed", IsCompleted },
			{ "objectives", objectiveData }
		};
	}
}

public interface IQuestObjective
{
	string Type { get; }
	string TargetId { get; }
	string Description { get; }
	int CurrentAmount { get; }
	int RequiredAmount { get; }
	bool IsCompleted { get; }

	bool HandleEvent(QuestEvent questEvent);
	string GetProgressText();
	Godot.Collections.Dictionary ToViewData();
}

public abstract class QuestObjectiveBase : IQuestObjective
{
	public string Type { get; }
	public string TargetId { get; }
	public string Description { get; }
	public int CurrentAmount { get; protected set; }
	public int RequiredAmount { get; }
	public bool IsCompleted => CurrentAmount >= RequiredAmount;

	protected QuestObjectiveBase(ObjectiveDefinition definition)
	{
		Type = definition.Type;
		TargetId = definition.TargetId;
		RequiredAmount = definition.RequiredAmount;
		Description = definition.Description;
		CurrentAmount = 0;
	}

	public virtual bool HandleEvent(QuestEvent questEvent)
	{
		if (IsCompleted)
			return false;

		if (questEvent.Type != Type || questEvent.TargetId != TargetId)
			return false;

		CurrentAmount = Math.Min(CurrentAmount + questEvent.Amount, RequiredAmount);
		return true;
	}

	public virtual string GetProgressText()
	{
		return $"{CurrentAmount}/{RequiredAmount}";
	}

	public virtual Godot.Collections.Dictionary ToViewData()
	{
		return new Godot.Collections.Dictionary
		{
			{ "type", Type },
			{ "target_id", TargetId },
			{ "description", Description },
			{ "current_amount", CurrentAmount },
			{ "required_amount", RequiredAmount },
			{ "progress_text", GetProgressText() },
			{ "is_completed", IsCompleted }
		};
	}
}

public sealed class CountObjective : QuestObjectiveBase
{
	public CountObjective(ObjectiveDefinition definition) : base(definition) { }
}

public static class ObjectiveFactory
{
	public static IQuestObjective Create(ObjectiveDefinition definition)
	{
		return definition.Type switch
		{
			"clean_trash" => new CountObjective(definition),
			"rescue_animal" => new CountObjective(definition),
			"collect_item" => new CountObjective(definition),
			"talk_npc" => new CountObjective(definition),
			"reach_area" => new CountObjective(definition),
			"plant_tree" => new CountObjective(definition),
			_ => throw new ArgumentException($"Unknown objective type: {definition.Type}")
		};
	}
}
