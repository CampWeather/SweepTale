using Godot;
using System;

public partial class pick_up_trash : RayCast3D
{
	[Export] public Node3D HandPosition;
	[Export] public Material OutlineMaterial;
	[Export] public StringName CarryableGroup = "CarryableTrash";
	[Export] public StringName PileGroup = "PileTrash";
	[Export] public StringName TrashGroup = "Sampah";
	[Export] public bool RemovePileAfterPickup = true;
	[Export] public float PilePickupHoldTime = 1.2f;

	private Node3D heldObject = null;
	private uint originalLayer;
	private uint originalMask;
	private float eHoldTimer = 0.0f;
	private readonly float throwHoldThreshold = 0.3f;
	private bool isTrackingHold = false;
	private bool justPickedUp = false;
	private Node3D targetedObject = null;
	private bool isTrackingPilePickup = false;
	private float pilePickupTimer = 0.0f;
	private Node3D pendingPileTrash = null;
	private ProgressBar pilePickupBar;

	public override void _Ready()
	{
		Enabled = true;
		CollideWithBodies = true;
		CollideWithAreas = true;
		
		pilePickupBar = GetTree().GetFirstNodeInGroup("pile_pickup_bar") as ProgressBar;
		
		if (pilePickupBar == null)
		{
			GD.PrintErr("PilePickupBar tidak ditemukan. Pastikan node ProgressBar sudah dimasukkan ke group 'pile_pickup_bar'.");
			return;
		}
		pilePickupBar.Visible = false;
		pilePickupBar.MinValue = 0;
		pilePickupBar.MaxValue = PilePickupHoldTime;
		pilePickupBar.Value = 0;
	}

public override void _Process(double delta)
{
	if (heldObject != null && HandPosition != null)
	{
		heldObject.GlobalTransform = HandPosition.GlobalTransform;
	}

	CheckForTarget();

	if (heldObject != null)
	{
		if (justPickedUp)
		{
			if (Input.IsActionJustReleased("interact"))
			{
				justPickedUp = false;
			}
			return;
		}

		if (Input.IsActionJustPressed("interact"))
		{
			GD.Print("Tekan dan tahan untuk melempar.");
			isTrackingHold = true;
			eHoldTimer = 0.0f;
		}

		if (isTrackingHold && Input.IsActionPressed("interact"))
		{
			eHoldTimer += (float)delta;
			if (eHoldTimer >= throwHoldThreshold)
			{
				ThrowObject();
				isTrackingHold = false;
				eHoldTimer = 0.0f;
			}
		}

		if (Input.IsActionJustReleased("interact"))
		{
			if (isTrackingHold)
			{
				isTrackingHold = false;
				eHoldTimer = 0.0f;
			}
		}

		return;
	}

	UpdatePilePickup((float)delta);
}

public override void _Input(InputEvent @event)
{
	if (@event.IsActionPressed("interact"))
	{
		if (heldObject == null)
		{
			ForceRaycastUpdate();

			if (IsColliding())
			{
				Node colliderNode = GetCollider() as Node;
				Node3D target = FindTargetableNode(colliderNode);

				if (target == null)
					return;

				if (target.IsInGroup("CarryableTrash"))
				{
					PickUpObject(target);
				}
				else if (target.IsInGroup("PileTrash"))
				{
					StartPilePickup(target);
				}
			}
		}
	}
	else if (@event.IsActionReleased("interact"))
	{
		if (heldObject == null)
		{
			CancelPilePickup();
		}
	}
	else if (@event.IsActionPressed("store_item"))
	{
		if (heldObject != null)
		{
			isTrackingHold = false;
			StoreToInventory();
		}
	}
}

	private void CheckForTarget()
	{
		if (heldObject != null)
		{
			SetOutline(targetedObject, false);
			targetedObject = null;
			return;
		}

		if (IsColliding())
		{
			Node colliderNode = GetCollider() as Node;
			Node3D target = FindTargetableNode(colliderNode);

			if (target != null)
			{
				if (target != targetedObject)
				{
					SetOutline(targetedObject, false);
					targetedObject = target;
					SetOutline(targetedObject, true);
				}
			}
			else
			{
				SetOutline(targetedObject, false);
				targetedObject = null;
			}
		}
		else
		{
			SetOutline(targetedObject, false);
			targetedObject = null;
		}
	}

	private Node3D FindTargetableNode(Node node)
	{
		while (node != null)
		{
			if (node.IsInGroup(CarryableGroup) || node.IsInGroup(PileGroup) || node.IsInGroup(TrashGroup))
			{
				return node as Node3D;
			}
			node = node.GetParent();
		}
		return null;
	}

	private void SetOutline(Node3D obj, bool enabled)
	{
		if (obj == null)
			return;

		if (obj is MeshInstance3D selfMesh)
		{
			selfMesh.MaterialOverlay = enabled ? OutlineMaterial : null;
		}

		SetOutlineRecursive(obj, enabled);
	}

	private void SetOutlineRecursive(Node node, bool enabled)
	{
		foreach (Node child in node.GetChildren())
		{
			if (child is MeshInstance3D meshInstance)
			{
				meshInstance.MaterialOverlay = enabled ? OutlineMaterial : null;
			}
			SetOutlineRecursive(child, enabled);
		}
	}

	private void PickUpObject(Node3D obj)
	{
		GD.Print("Memegang objek: " + obj.Name);
		heldObject = obj;
		SetOutline(heldObject, false);

		if (heldObject is RigidBody3D rb)
		{
			originalLayer = rb.CollisionLayer;
			originalMask = rb.CollisionMask;
			rb.FreezeMode = RigidBody3D.FreezeModeEnum.Kinematic;
			rb.Freeze = true;
			rb.CollisionLayer = 0;
			rb.CollisionMask = 0;
		}

		justPickedUp = true;
		isTrackingHold = false;
		eHoldTimer = 0.0f;
	}

	private void PickPileTrash(Node3D obj)
	{
		GD.Print("Memungut PileTrash: " + obj.Name);
		SetOutline(obj, false);
		if (targetedObject == obj)
			{
				targetedObject = null;
			}
		// Tambahkan ke inventory di sini kalau perlu
		// Example:
		// InventoryManager.Instance.Add("PileTrash");
		obj.QueueFree();
	}

	private void ThrowObject()
	{
		GD.Print("Melempar objek (Hold E): " + heldObject.Name);

		if (heldObject is RigidBody3D rb)
		{
			rb.Freeze = false;
			rb.CollisionLayer = originalLayer;
			rb.CollisionMask = originalMask;

			Vector3 throwDirection = -GlobalTransform.Basis.Z;
			float throwForce = 15.0f;
			rb.ApplyImpulse(throwDirection * throwForce);
		}

		heldObject = null;
	}

	private void StoreToInventory()
	{
		GD.Print("Sukses menyimpan " + heldObject.Name + " ke inventory.");
		heldObject.QueueFree();
		heldObject = null;
	}
	
	private void StartPilePickup(Node3D obj)
	{
		if (pilePickupBar == null) return;
		
		if (obj == null)
		return;

		if (!obj.IsInGroup("PileTrash"))
		return;

		if (pendingPileTrash == obj && isTrackingPilePickup)
		return;

		pendingPileTrash = obj;
		isTrackingPilePickup = true;
		pilePickupTimer = 0.0f;

		UpdatePilePickupUI(0.0f);
		pilePickupBar.Visible = true;
		pilePickupBar.Value = pilePickupTimer;
	}

	private void UpdatePilePickup(float delta)
	{
		if (!isTrackingPilePickup)
		return;

		if (pendingPileTrash == null)
		{
			CancelPilePickup();
			return;
		}

		if (!Input.IsActionPressed("interact"))
		{
			CancelPilePickup();
			return;
		}

		ForceRaycastUpdate();

		Node3D currentTarget = null;

		if (IsColliding())
		{
			Node colliderNode = GetCollider() as Node;
			currentTarget = FindTargetableNode(colliderNode);
		}

		if (currentTarget != pendingPileTrash)
		{
			CancelPilePickup();
			return;
		}

		pilePickupTimer += delta;

		float progress = Mathf.Clamp(pilePickupTimer / PilePickupHoldTime, 0.0f, 1.0f);
		UpdatePilePickupUI(progress);

		if (pilePickupTimer >= PilePickupHoldTime)
		{
			Node3D pickedTarget = pendingPileTrash;
			CancelPilePickup();
			PickPileTrash(pickedTarget);
		}
	}
	
	private void CancelPilePickup()
	{
		isTrackingPilePickup = false;
		pilePickupTimer = 0.0f;
		pendingPileTrash = null;
		UpdatePilePickupUI(0.0f, false);
	}
	
	private void UpdatePilePickupUI(float progress, bool visible = true)
	{
		if (pilePickupBar == null)
		return;

		pilePickupBar.Visible = visible;
		pilePickupBar.Value = pilePickupTimer;
	}
	
	 private void ResetPilePickupUI()
	{
		if (pilePickupBar == null) return;
		pilePickupBar.Visible = false;
		pilePickupBar.Value = 0;
		}
}
