using Godot;
using System;

public partial class pick_up_trash : RayCast3D
{
	[Export] public Node3D HandPosition;
	[Export] public Material OutlineMaterial; // Tambahkan parameter untuk material outline

	private Node3D heldObject = null;
	private uint originalLayer;
	private uint originalMask;
	private float eHoldTimer = 0.0f;
	private float throwHoldThreshold = 0.3f;

	private bool isTrackingHold = false;
	private bool justPickedUp = false;

	private Node3D targetedObject = null; // Tambahkan referensi ke objek yang ditargetkan

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

		// Logika Penyorotan/Outline (Soroti objek SEBELUM interaksi)
		CheckForTarget();

		// Logika Pegangan (Holding)
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
					// EholdTimer < threshold, jangan melempar di sini.
					isTrackingHold = false;
					eHoldTimer = 0.0f;
				}
			}
		}
	}

	public override void _Input(InputEvent @event)
	{
		// Logika Interaksi (Ambil/Simpan)
		if (@event.IsActionPressed("interact"))
		{
			if (heldObject == null)
			{
				// Hanya izinkan pengambilan jika tidak memegang apa pun
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
		else if (@event.IsActionPressed("store_item"))
		{
			if (heldObject != null)
			{
				isTrackingHold = false;
				StoreToInventory();
			}
		}
	}

	// Baru: Periksa objek yang ditargetkan dan aktifkan outline
	private void CheckForTarget()
	{
		if (heldObject != null)
		{
			// Jika memegang objek, jangan soroti yang lain
			SetOutline(targetedObject, false);
			targetedObject = null;
			return;
		}

		if (IsColliding())
		{
			Node3D collider = (Node3D)GetCollider();
			if (collider.IsInGroup("CarryableTrash"))
			{
				if (collider != targetedObject)
				{
					// Nonaktifkan outline pada objek target lama
					SetOutline(targetedObject, false);
					
					// Soroti objek target baru
					targetedObject = collider;
					SetOutline(targetedObject, true);
				}
			}
			else
			{
				// Tabrakan dengan objek non-sampah, matikan outline target lama
				SetOutline(targetedObject, false);
				targetedObject = null;
			}
		}
		else
		{
			// Tidak ada tabrakan, matikan outline target lama
			SetOutline(targetedObject, false);
			targetedObject = null;
		}
	}

	// Baru: Fungsi untuk mengaktifkan/menonaktifkan outline pada MeshInstance3D
	private void SetOutline(Node3D obj, bool enabled)
	{
		if (obj == null) return;

		// Cari MeshInstance3D di bawah objek
		MeshInstance3D meshInstance = obj.GetNodeOrNull<MeshInstance3D>("MeshInstance3D");
		if (meshInstance != null)
		{
			if (enabled)
			{
				// Terapkan outline sebagai material overrider
				meshInstance.MaterialOverlay = OutlineMaterial;
			}
			else
			{
				// Hapus material overrider untuk menonaktifkan outline
				meshInstance.MaterialOverlay = null;
			}
		}
	}

	private void PickUpObject(Node3D obj)
	{
		GD.Print("Memegang objek: " + obj.Name);
		heldObject = obj;

		// Baru: Nonaktifkan outline pada objek yang dipegang segera
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
