using Godot;
using System;

public partial class pick_up_trash : RayCast3D
{
	[Export] public Node3D HandPosition; 
	
	private Node3D heldObject = null;

	private uint originalLayer;
	private uint originalMask;

	private float eHoldTimer = 0.0f;
	private float throwHoldThreshold = 0.3f; 
	private bool isTrackingHold = false;
	private bool justPickedUp = false; 

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
				isTrackingHold = false;
				eHoldTimer = 0.0f;
			}
		}
	}

	public override void _Input(InputEvent @event)
	{
		if (heldObject == null)
		{
			if (@event.IsActionPressed("interact"))
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
		}
		else
		{
			if (@event.IsActionPressed("store_item"))
			{
				isTrackingHold = false; 
				StoreToInventory();
			}
		}
	}

	private void PickUpObject(Node3D obj)
	{
		GD.Print("Memegang objek: " + obj.Name);
		heldObject = obj;

		if (heldObject is RigidBody3D rb)
		{
			originalLayer = rb.CollisionLayer;
			originalMask = rb.CollisionMask;

			rb.Freeze = true;
			rb.CollisionLayer = 0;
			rb.CollisionMask = 0;
		}

		justPickedUp = true;
		isTrackingHold = false;
		eHoldTimer = 0.0f;
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
}
