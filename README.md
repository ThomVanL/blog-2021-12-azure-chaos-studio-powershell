# Azure Chaos Studio and PowerShell

## Chaos experiments with Pester 5

I had some spare time last month and decided it was time to [take a closer look at Azure Chaos Studio](https://github.com/ThomVanL/blog-2021-11-azure-chaos-studio), which is __a managed service__ that allows you to __orchestrate fault injection__ on your Azure resources, or inside of virtual machines, in a controlled manner. It helps you to perform chaos engineering on the Azure platform. Before my encounter with Azure Chaos Studio, I had also tinkered with [Chaos Toolkit](https://chaostoolkit.org/). It is open-source software that can be used to perform chaos engineering experiments.

### "Quick Question"

A friend of mine asked me whether I could combine PowerShell, Pester 5 (a test and mock framework for PowerShell) and Azure Chaos Studio, in order to perform chaos experiments in a similar fashing to how Chaos Toolkit does it.  If I wanted to tackle this I figured I'd have to go back and see what a Chaos Toolkit experiment consists of. When you run a Chaos Toolkit experiment, the following actions take place:

- A first check (or pass, as I refer to it) of the steady-state hypothesis.
  - Defines what the working state of our app should be.
  - For example: does this call to our web page return a status code 200?
- A method block.
  - Changes the conditions of our system.
  - For example: block incoming traffic on the firewall.
- A second pass of the same steady-state hypothesis.
  - This is to validate that everything is still working as intended.
- A rollback block
  - Does what it needs to, to roll back the changes introduced by the method block.

The method, second steady-state hypothesis pass and rollback blocks can only be executed when the first steady-state hypothesis pass was completed succesfully.

After reading through all that, wasn't quite certain whether I could build something similar with PowerShell and Pester 5... But I think I've managed to come up with something that can work, after all.

Feel free to read the [full blog post](https://thomasvanlaere.com/posts/2021/12/azure-chaos-studio-and-powershell/)!

## Required Azure Resources

You will need to run the Pester (chaos experiment) test against! The following template creates a simple web server, which will be sitting in a web subnet on the virtual network, a network security group will be associated with the web subnet. Through the use of a chaos experiment, we will inject a faulty inbound rule, in the network security group, for just a few minutes. This should cause the website to become unreachable!


[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FThomVanL%2Fblog-2021-11-azure-chaos-studio%2Fmain%2Farm-templates%2Fcomplete%2Fazuredeploy.json)

[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2FThomVanL%2Fblog-2021-11-azure-chaos-studio%2Fmain%2Farm-templates%2Fcomplete%2Fazuredeploy.json)