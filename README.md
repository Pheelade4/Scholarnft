# 🎓 ScholarNFT - Milestone-Based Student Funding

> Empowering education through blockchain-powered scholarship management with milestone-based fund releases.

## 🌟 Overview

ScholarNFT is a revolutionary smart contract platform built on Stacks that transforms how scholarships are managed and distributed. By combining NFTs with milestone-based funding, we create transparency, accountability, and trust between sponsors and students.

## ✨ Key Features

- 🎯 **Milestone-Based Funding**: Funds are released as students complete verified milestones
- 🏆 **NFT Certificates**: Each scholarship is represented as a unique NFT
- 👥 **Dual Profiles**: Separate profiles for students and sponsors
- 🔍 **Transparent Tracking**: Real-time progress monitoring for all stakeholders
- ✅ **Verification System**: Built-in milestone verification and approval process
- 💰 **Secure Escrow**: Funds are held securely until milestones are completed

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
git clone <your-repo>
cd scholarnft
clarinet check
```

## 📖 Usage Guide

### For Students 👨‍🎓

1. **Create Your Profile**
   ```clarity
   (contract-call? .Scholarnft create-student-profile 
     "John Doe" 
     "Computer Science" 
     "MIT" 
     u350)  ;; GPA * 100
   ```

2. **Complete Milestones**
   ```clarity
   (contract-call? .Scholarnft complete-milestone u1 u1)
   ```

### For Sponsors 🏢

1. **Create Sponsor Profile**
   ```clarity
   (contract-call? .Scholarnft create-sponsor-profile 
     "Tech Corp" 
     "Technology Company")
   ```

2. **Create Scholarship**
   ```clarity
   (contract-call? .Scholarnft create-scholarship 
     'ST1STUDENT... 
     u10000000  ;; 10 STX
     u4)        ;; 4 milestones
   ```

3. **Add Milestones**
   ```clarity
   (contract-call? .Scholarnft add-milestone 
     u1 
     u1 
     "Complete first semester with 3.5+ GPA" 
     u2500000)  ;; 2.5 STX
   ```

4. **Verify and Release Funds**
   ```clarity
   (contract-call? .Scholarnft verify-and-release-funds u1 u1)
   ```

## 🔧 Contract Functions

### Public Functions

| Function | Description |
|----------|-------------|
| `create-student-profile` | Register as a student with academic details |
| `create-sponsor-profile` | Register as a sponsor organization |
| `create-scholarship` | Create new scholarship with milestone structure |
| `add-milestone` | Define specific milestones for a scholarship |
| `complete-milestone` | Student marks milestone as completed |
| `verify-and-release-funds` | Sponsor verifies milestone and releases funds |

### Read-Only Functions

| Function | Description |
|----------|-------------|
| `get-scholarship` | Get scholarship details |
| `get-milestone` | Get specific milestone information |
| `get-student-profile` | Retrieve student profile |
| `get-sponsor-profile` | Retrieve sponsor profile |
| `get-scholarship-progress` | Get completion percentage and progress |

## 📊 Data Structure

### Scholarship Structure
```clarity
{
  student: principal,
  sponsor: principal,
  total-amount: uint,
  claimed-amount: uint,
  milestones-completed: uint,
  total-milestones: uint,
  active: bool,
  created-at: uint
}
```

### Milestone Structure
```clarity
{
  description: string-ascii,
  amount: uint,
  completed: bool,
  verified-by: optional principal,
  completed-at: optional uint
}
```



