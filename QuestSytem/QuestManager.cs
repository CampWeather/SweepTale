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
[Signal] public delegate void QuestTurnedInEventHandler(string questId);
[Signal] public delegate void QuestListChangedEventHandler();

[Signal] public delegate void CloverChangedEventHandler(int newTotal);
[Signal] public delegate void CloverRewardGrantedEventHandler(string questId, int amount, int newTotal);


	private readonly Dictionary<string, QuestDefinition> _definitions = new();
	private readonly Dictionary<string, QuestInstance> _activeQuests = new();
	private readonly HashSet<string> _completedQuests = new();
	
	private int _cloverLeaves = 0;


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

	public bool CanTurnInQuest(string questId)
	{
		return _activeQuests.TryGetValue(questId, out QuestInstance quest)
			&& quest.Status == QuestStatus.Completed
			&& !quest.RewardsClaimed;
	}

	public string GetQuestStatus(string questId)
	{
		if (_activeQuests.TryGetValue(questId, out QuestInstance quest))
			return quest.Status.ToString();

		if (_completedQuests.Contains(questId))
			return QuestStatus.TurnedIn.ToString();

		return QuestStatus.Locked.ToString();
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

		if (quest.Status != QuestStatus.Active)
			return;

		quest.Status = QuestStatus.Completed;

		EmitSignal(SignalName.QuestCompleted, questId);

		if (!quest.HasRewards)
		{
			FinalizeQuestTurnIn(quest);
			return;
		}

		EmitSignal(SignalName.QuestListChanged);
	}


	public bool IsQuestActive(string questId)
	{
		return _activeQuests.ContainsKey(questId);
	}

	public bool IsQuestCompleted(string questId)
	{
		if (_completedQuests.Contains(questId))
			return true;

		if (_activeQuests.TryGetValue(questId, out QuestInstance quest))
			return quest.Status == QuestStatus.Completed || quest.Status == QuestStatus.TurnedIn;

		return false;
	}

	public bool IsQuestTurnedIn(string questId)
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
			new("clean_trash", "PileTrash", 5, "Bersihkan 5 Tumpukan Sampah")
		},
		rewards: new List<RewardDefinition>
		{
			new("clover", 120, description: "120 Clover Leaves")
		},
		turnInDescription: "Temuilah Kola untuk mendapatkan hadiah."
	);
		
		QuestDefinition talkToNPC = new(
			id: "talk_to_Dzakwan",
			title: "Bicaralah dengan Kola",
			description: "Temui Penduduk disekitar sini dan tanyai apa yang terjadi dengan hutan.",
			objectives: new List<ObjectiveDefinition>
	{
		new("talk_npc", "NPC_01", 1, "Temui Kola")
	}
);

		_definitions[talkToNPC.Id] = talkToNPC;
		_definitions[cleanTrash.Id] = cleanTrash;
	}

	public void TurnInQuest(string questId)
	{
		if (!_activeQuests.TryGetValue(questId, out QuestInstance quest))
			return;

		if (quest.Status != QuestStatus.Completed)
			return;

		if (quest.RewardsClaimed)
			return;

		FinalizeQuestTurnIn(quest);
	}


	public int GetCloverLeaves()
	{
		return _cloverLeaves;
	}

	public void SetCloverLeaves(int value)
	{
		_cloverLeaves = Math.Max(0, value);
		EmitSignal(SignalName.CloverChanged, _cloverLeaves);
	}

	public void AddCloverLeaves(int amount, string sourceQuestId = "")
	{
		if (amount <= 0)
			return;

		_cloverLeaves = Math.Max(0, _cloverLeaves + amount);

		EmitSignal(SignalName.CloverChanged, _cloverLeaves);

		if (!string.IsNullOrEmpty(sourceQuestId))
			EmitSignal(SignalName.CloverRewardGranted, sourceQuestId, amount, _cloverLeaves);
	}
	
	private void FinalizeQuestTurnIn(QuestInstance quest)
	{
		if (!quest.RewardsClaimed)
		{
			QuestRewardContext context = new(this, quest);

			foreach (IQuestReward reward in quest.Rewards)
				reward.Apply(context);

			quest.MarkRewardsClaimed();
		}

		quest.Status = QuestStatus.TurnedIn;

		_activeQuests.Remove(quest.Id);
		_completedQuests.Add(quest.Id);

		EmitSignal(SignalName.QuestTurnedIn, quest.Id);
		EmitSignal(SignalName.QuestListChanged);
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
	public string TurnInDescription { get; }
	public IReadOnlyList<ObjectiveDefinition> Objectives { get; }
	public IReadOnlyList<RewardDefinition> Rewards { get; }

	public QuestDefinition(
		string id,
		string title,
		string description,
		IReadOnlyList<ObjectiveDefinition> objectives,
		IReadOnlyList<RewardDefinition> rewards = null,
		string turnInDescription = ""
	)
	{
		if (string.IsNullOrWhiteSpace(id))
			throw new ArgumentException(
				"Quest ID tidak boleh kosong.",
				nameof(id)
			);

		Id = id;
		Title = title ?? string.Empty;
		Description = description ?? string.Empty;
		TurnInDescription = turnInDescription ?? string.Empty;
		Objectives = objectives ?? Array.Empty<ObjectiveDefinition>();
		Rewards = rewards ?? Array.Empty<RewardDefinition>();
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

public sealed class RewardDefinition
{
	public string Type { get; }
	public int Amount { get; }
	public string TargetId { get; }
	public string Description { get; }

	public RewardDefinition(string type, int amount, string targetId = "", string description = "")
	{
		Type = type;
		Amount = Math.Max(1, amount);
		TargetId = targetId;
		Description = description;
	}
}

public sealed class QuestInstance
{
	public string Id => Definition.Id;
	public QuestDefinition Definition { get; }
	public QuestStatus Status { get; set; }
	public List<IQuestObjective> Objectives { get; }
	public List<IQuestReward> Rewards { get; }
	public bool RewardsClaimed { get; private set; }
	public bool IsCompleted => Objectives.All(objective => objective.IsCompleted);
	public bool HasRewards => Rewards.Count > 0;

	private QuestInstance(QuestDefinition definition, List<IQuestObjective> objectives, List<IQuestReward> rewards)
	{
		Definition = definition;
		Objectives = objectives;
		Rewards = rewards;
		Status = QuestStatus.Available;
		RewardsClaimed = false;
	}

	public string GetDisplayDescription()
	{
		if (
			Status == QuestStatus.Completed
			&& HasRewards
			&& !string.IsNullOrWhiteSpace(Definition.TurnInDescription)
		)
		{
			return Definition.TurnInDescription;
		}

		return Definition.Description;
	}


	public static QuestInstance FromDefinition(QuestDefinition definition)
	{
		List<IQuestObjective> objectives = definition.Objectives
			.Select(ObjectiveFactory.Create)
			.ToList();

		List<IQuestReward> rewards = definition.Rewards
			.Select(RewardFactory.Create)
			.ToList();

		return new QuestInstance(definition, objectives, rewards);
	}

	public void MarkRewardsClaimed()
	{
		RewardsClaimed = true;
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
		{
			objectiveData.Add(objective.ToViewData());
		}

		Godot.Collections.Array<Godot.Collections.Dictionary> rewardData = new();

		foreach (IQuestReward reward in Rewards)
		{
			rewardData.Add(reward.ToViewData());
		}

		bool needsTurnIn =
			Status == QuestStatus.Completed
			&& HasRewards
			&& !RewardsClaimed;

		return new Godot.Collections.Dictionary
		{
			{ "id", Id },
			{ "title", Definition.Title },

		// Ini yang dipakai Quest UI sebagai teks utama.
			{ "description", GetDisplayDescription() },

		// Optional, tapi berguna untuk UI/debug nanti.
			{ "base_description", Definition.Description },
			{ "turn_in_description", Definition.TurnInDescription },
			{ "status", Status.ToString() },
			{ "is_completed", IsCompleted },
			{ "rewards_claimed", RewardsClaimed },
			{ "has_rewards", HasRewards },
			{ "needs_turn_in", needsTurnIn },

			{ "objectives", objectiveData },
			{ "rewards", rewardData }
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

public interface IQuestReward
{
	string Type { get; }
	int Amount { get; }
	string TargetId { get; }
	string Description { get; }

	void Apply(QuestRewardContext context);
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

public sealed class QuestRewardContext
{
	public QuestManager QuestManager { get; }
	public QuestInstance Quest { get; }

	public QuestRewardContext(QuestManager questManager, QuestInstance quest)
	{
		QuestManager = questManager;
		Quest = quest;
	}
}

public sealed class CloverReward : IQuestReward
{
	public string Type { get; }
	public int Amount { get; }
	public string TargetId { get; }
	public string Description { get; }

	public CloverReward(RewardDefinition definition)
	{
		Type = definition.Type;
		Amount = definition.Amount;
		TargetId = definition.TargetId;
		Description = string.IsNullOrEmpty(definition.Description)
			? $"{Amount} Clover Leaves"
			: definition.Description;
	}

	public void Apply(QuestRewardContext context)
	{
		context.QuestManager.AddCloverLeaves(Amount, context.Quest.Id);
	}

	public Godot.Collections.Dictionary ToViewData()
	{
		return new Godot.Collections.Dictionary
		{
			{ "type", Type },
			{ "amount", Amount },
			{ "target_id", TargetId },
			{ "description", Description }
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

public static class RewardFactory
{
	public static IQuestReward Create(RewardDefinition definition)
	{
		return definition.Type switch
		{
			"clover" => new CloverReward(definition),
			_ => throw new ArgumentException($"Unknown reward type: {definition.Type}")
		};
	}
}
