using Godot;
using System;

public partial class pick_up_trash : RayCast3D
{
	[Export] public Node3D HandPosition; 
	
	private Node3D heldObject = null;

	public override void _Ready()
	{
		Enabled = true; 
	}
	
	public override void _Process(double delta)
	{
		if (heldObject != null && HandPosition != null)
		{
			heldObject.GlobalTransform = HandPosition.GlobalTransform;
		}
	}

	public override void _Input(InputEvent @event)
	{
		if (@event.IsActionPressed("interact") && heldObject == null)
		{
			if (IsColliding())
			{
				Node3D collider = (Node3D)GetCollider();
				
				if (collider.IsInGroup("CarryableTrash"))
				{
					PickUpObject(collider);
				}
			}
		}

		if (@event.IsActionPressed("store_item") && heldObject != null)
		{
			StoreToInventory();
		}
	}

	private void PickUpObject(Node3D obj)
	{
		GD.Print("Memegang objek: " + obj.Name);
		heldObject = obj;

		if (heldObject is RigidBody3D rb)
		{
			rb.Freeze = true;
			rb.CollisionLayer = 0;
			rb.CollisionMask = 0;
		}
	}

	private void StoreToInventory()
	{
		GD.Print("Sukses menyimpan " + heldObject.Name + " ke inventory.");
		heldObject.QueueFree(); 
		heldObject = null; 
	}
}
