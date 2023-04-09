# homelab
Live config for my homelab

Some of this will be either depending on stuff in [nomad-homelab](https://www.github.com/gerrowadat/nomad-homelab/) 
or otherwise incomplete because of secrets or something, I'll try to comment where this is true.

Is it a bad idea? Maybe. But I figured this might be fun in case anyone has better ideas, might learn something,
or just wants to point and laugh. I will apply the general principle of #worksonmycluster here; this isn't how I'd do
things in production, but it's good enough for a close to zero-consequences cluster I can rebuild in an afternoon
at close to zero cost :-)

Basic 'Design'
==============

The 'lab' part of my home network is actually the bit that runs 'infrastructure' and apps above the basic network level.
My network kit runs DHCP, but I run DNS directly (with a fallback to the router that just defers everything to Google's DNS)

There's a QNAP NAS called `tings` that has about 4TB of storage, and is creaky and old. I'd like to get rid of it maybe at
some point if I ever pull the trigger on something that will take a bunch of 4TB drives and DTRT.

There are 2 main types of host:

 - pi cluster nodes - These are Raspberry Pi Model 4 B 8GB nodes, in a cluster enclosue with their own switch and uplink. They're powered via PoE HATs so only the switch needs a wallwart. `picluster1...4` are in this enclosure, `picluster5` is attached to the 3d printer and mainly runs octoprint.
 
 - More Powerful nodes. These generally have m.2 onboard root disks and separate 1TB SSDs.
     - `hedwig` is an older intel NUC. It shares a UPS with the QNAP NAS (`tings`) that I'm trying to get rid of.
     - `rabbitseason` is a newer-generation NUC; it also doubles as a desktop machine in the office. Power not protected.
     - `duckseason` is an odroid of some kind, I think. It shares a UPS with the networking kit/router.

All the above run either raspbian or whatever the most up to date Ubuntu LTS was the last time I reinstalled them.

Anything else on the network is going to get a dynamic IP and move around.

Base Images and assumptions
===========================

See the 'ansible' directory for who gets what. All the above hosts are nomad clients and servers, as well as running consul.

It's assumed all these hosts will have the following mounts:

  - /mnt/docker - NFS shared from `tings` that has docker configs and probably other stuff that shouldn't be there.
  - /mnt/media - uh, linux ISOs. NFS share from `tings`.
  - /things - NFS share from `duckseason` that's a helluva lot faster than /mnt/docker and that I'll probably move stuff to.

There may be one or two things that use local storage because either it needs to be fast, or software that doesn't like talking to
NFS or fuse (home assistant occasionally corrupts its database for this reason). I also have an awful hack for nomad to get around that
-- but we're getting ahead of ourselves.

This Repo
=========

I'll try to keep stuff commented and documented, but a lot of this stuff should be self-explanatory.

[playbook.md](playbook.md) is a simple playbook for doing various things.

[backpack.sh](backpack.sh) is a script/playbook for restoring from scratch.
