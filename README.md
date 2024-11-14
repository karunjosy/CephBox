# CephBox

## CephBox - A home cloud personal storage solution

### Why Cephbox?

This project aims to solve a common problem with personal data storage and management. While we have many solutions for business-critical data, personal data is often overlooked.

I have been  struggling with storing the photos and videos that I take. My cloud storage is running out and I am hesitant to upgrade the plan. I struggle to keep a track of all the USB sticks and hard disks lying around, and I have a lot of them. And they have a short shell life and I am pretty sure couple of them are already dead. I see the same story with everyone in my family and my friends. Just think of the  social media content creators and photographers out there who is having hard time dealing with the storage and management. 

Ofcourse, there are cloud storage solutions  but it is an overkill in respect to the high end resources that a provider needs to manage for 'personal data' because personal data is bit unique in nature, although it does not have monetary value associated to it, it has tremendous emotional value for the individual. 
And Cloud storage is quite expensive!

There should be a de-centralized alternative cheap hybrid solution for personal data storage without cutting off the benefits of cloud storage.  

### What is CephBox?

I wanted to see if Ceph can be used as a backend for a home NAS setup and develop an end to end personal data storage solution

I belive Ceph has all the potential needed for this because of the unique features it has. Ceph is designed to be an enterprise grade product but it has the flexibility to be molded for any type of use.

I have listed out here some of the advantages of using Ceph like
- low cost setup
- Data can be stored and accessed as objects, filesystem or block devices according to the use case
- we can create a perfect back up solution using existing cloud archival services to ensure data durability

### What are the major components involved?

I envision these would be the 4 major components involved eventually

- a sleek compact hardware box where we will have multiple small form factored cpus and SSDs/HDDs installed to create a ceph cluster
- Ceph as the storage software primarily using RGW to automatically upload the data from the mobile phones and other devices
- A webserver interface to get started with the setting up of the cluster and initializing pools and users. Ceph dashboard is quite handy for it but maybe a customized minimal and tailor fit one for this box can be thought about.
- A mobile or desktop app similar to Google photos or drive or any file manager to access the phots and vides from the cephbox in which we can configure the automatic upload to the ceph cluster


### What are some of the Value Propositions: What unique benefits or solutions does this project bring?

First is the concept of home cloud setup, It could be argued the same benefits and considerations driving the IT enterprise industry's move towards a hybrid cloud  are equally relevant for personal data storage. 
And the matter of fact  personal data storage consumption is growing and I believe that eventually 2 things will happen; either the cloud storage would become completely free(which I highly doubt) or else Storage would evolve to be a home appliance. And Ceph is the perfect choice for it.  

And Now how about this thought, A ceph cluster in every home.
We refer to Ceph as the "Linux of storage," and for that to hold true, it needs broader adoption. more number of people should be using it and this project is the most simple and straightforward path to making that a reality.


### Purpose and thoughts:

I am still skeptical if this is a good idea or not because I am pragmatic and I see way more challenges in the project; maybe the world and the people are not ready for home cloud concept, maybe software and hardware is not mature enough to accomplish this, maybe Ceph is not the perfect choice. 

But I strongly believe the problem of personal data storage and management exists in the world now, (although it maybe not that severe yet.) And majority of the world does not know there could be a better solution than that what we currently have. 

And I would like to approach this problem on a broader philosophical level;

Humans have an evolutionary instinct to document their memories, be it may cave paintings or diary or photographs or videos or 24* 7 bodycams(with spatial videos) in future.
Personal data storage will continue to increase unless we develop a new codec to severly compress the original artifact with its same quality. 

So the most important question is:
Is public cloud storage the perfect solution for personal data storage? Not only from a technical perspective, but also considering ethical, ecological, and economic aspects?

I did some numbers to estimate the data storage requirement for a family with the current rate;
Assuming a person takes 1 photo per day and records 1 minute of video per day;
If it's a family of 4, that's around 200GB new data generated each year; 
Then there's your constant and long living core life event memories like
  - your wedding album and video which adds up another 50GB
  - your child's first birthday, first dance performance etc - 20GB
  - your learning stuff - 10 GB
  - I am sure 90% of the people have another 20GB photo/video of their dog and cat.

So a total 2 TB is required to store your memories for the next couple of years. But how about 20 years from now? Will it become 10x or 100x?

And let's be honest, half of the photos are not that great. Perhaps only 10% are worth keeping and even those might  not be revisited for years. But reality is we eventually do look back at them.
Nostalgia and reminiscence are potent human emotions and powerful motivators. 

One could use multiple external Hard disks and USBs to manage it. I tried and I genuienly hate it. 

I assume the public cloud providers are using the most sophisticated, most technology advanced software and hardware to store our data. But my argument is, it is an overkill because of this unique nature of personal data.
I believe cloud providers should act more like a gatekeeper or Dwarapalakas or Sphinx, to be a bridge to our home storage appliance and also help to archive the data to create a safe copy on a remote site and safeguard it. 

Another important aspect is that current public cloud solutions encourage us to create more data wastage(referring to the point that only 10% of our photos are good). But rather than increasing the total data consumption, intelligent software should help to clear the clutter and minimize the wastage. 

This is the very crux of the project and if the above arguments are wrong, then I don't think this project will have any real world value :) Of course, we can continue it as a DIY home project to learn more personally but just that. 

And on the commercial perspective, this is the arguement that I prepared to convince myself;

What if Apple Microsoft or Google announces a Home cloud storage box tomorrow with these features;

- 8 TB Storage for unlimited users
- 200 GB cloud space - your most recent 6 months data will be cached and stored in google cloud for faster access. Old data will be moved to the storage box in your home. You can still access all your old data from anywhere in the world anytime if the device is powered on and you have network connection(ofcourse not that fast as it has to pass through relay servers)
- full privacy feature (option to not store the photos in cloud)
- 1 TB free(or a very minimal cost) archival space for your very essential data that you dont want ever to loose, maybe archived once a month fully encrypted. If something happens and you need to restore then that would only cost you.
- Siri or Google assistant on the storage box (something like amazon alexa)
- A home automation platform included
- And the price is 30,000 Rs (less than what it costs for 4 year of cloud storage) 

I am pretty sure that I would buy this the first day of it's launch :)
